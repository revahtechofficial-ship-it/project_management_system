package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

type reactionHit struct {
	MessageID int64  `json:"message_id"`
	Emoji     string `json:"emoji"`
	UserID    int64  `json:"user_id"`
}

// listReactions returns every reaction on a conversation's messages so the
// client can render counts and "mine" state.
func (h *ChatHandler) listReactions(w http.ResponseWriter, r *http.Request) {
	convID, _, ok := h.authConv(w, r)
	if !ok {
		return
	}
	rows, err := h.q.ListReactionsForConversation(r.Context(), convID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]reactionHit, 0, len(rows))
	for _, row := range rows {
		out = append(out, reactionHit{
			MessageID: row.MessageID,
			Emoji:     row.Emoji,
			UserID:    row.UserID,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

// toggleReaction adds the caller's reaction to a message, or removes it if it is
// already present, then broadcasts the change.
func (h *ChatHandler) toggleReaction(w http.ResponseWriter, r *http.Request) {
	actor, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	mid, err := strconv.ParseInt(chi.URLParam(r, "messageId"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b struct {
		Emoji string `json:"emoji"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	emoji := strings.TrimSpace(b.Emoji)
	if emoji == "" {
		writeError(w, http.StatusBadRequest, errors.New("emoji is required"))
		return
	}
	msg, err := h.q.GetMessageWithSender(r.Context(), mid)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("message not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if _, member := h.memberRole(r.Context(), msg.ConversationID, actor); !member {
		writeError(w, http.StatusForbidden, errors.New("not a member of this conversation"))
		return
	}

	has, _ := h.q.HasReaction(r.Context(), db.HasReactionParams{
		MessageID: mid, UserID: actor, Emoji: emoji,
	})
	if has {
		err = h.q.RemoveReaction(r.Context(), db.RemoveReactionParams{
			MessageID: mid, UserID: actor, Emoji: emoji,
		})
	} else {
		err = h.q.AddReaction(r.Context(), db.AddReactionParams{
			MessageID: mid, UserID: actor, Emoji: emoji,
		})
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.broadcastReaction(r.Context(), msg.ConversationID, mid, emoji, actor, !has)
	w.WriteHeader(http.StatusNoContent)
}

func (h *ChatHandler) broadcastReaction(ctx context.Context, convID, msgID int64,
	emoji string, userID int64, added bool) {
	ids, err := h.q.ConversationMemberIDs(ctx, convID)
	if err != nil {
		return
	}
	payload, err := json.Marshal(map[string]any{
		"type":            "reaction",
		"conversation_id": convID,
		"message_id":      msgID,
		"emoji":           emoji,
		"user_id":         userID,
		"added":           added,
	})
	if err != nil {
		return
	}
	h.hub.SendToUsers(ids, payload)
}

// editMessage updates the body of a text message owned by the caller and
// broadcasts the new content.
func (h *ChatHandler) editMessage(w http.ResponseWriter, r *http.Request) {
	actor, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	mid, err := strconv.ParseInt(chi.URLParam(r, "messageId"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b struct {
		Body string `json:"body"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	body := strings.TrimSpace(b.Body)
	if body == "" {
		writeError(w, http.StatusBadRequest, errors.New("message is empty"))
		return
	}
	msg, err := h.q.GetMessageWithSender(r.Context(), mid)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("message not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if msg.SenderID == nil || *msg.SenderID != actor {
		writeError(w, http.StatusForbidden, errors.New("only the sender can edit this message"))
		return
	}
	if msg.Kind != "text" {
		writeError(w, http.StatusBadRequest, errors.New("only text messages can be edited"))
		return
	}
	if err := h.q.UpdateMessageBody(r.Context(), db.UpdateMessageBodyParams{
		ID: mid, Body: body,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	row, err := h.q.GetMessageWithSender(r.Context(), mid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	mr := messageFromGet(row)
	if ids, e := h.q.ConversationMemberIDs(r.Context(), msg.ConversationID); e == nil {
		if payload, me := json.Marshal(map[string]any{
			"type":            "message_edited",
			"conversation_id": msg.ConversationID,
			"message":         mr,
		}); me == nil {
			h.hub.SendToUsers(ids, payload)
		}
	}
	writeJSON(w, http.StatusOK, mr)
}
