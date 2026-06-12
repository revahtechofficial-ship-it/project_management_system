package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// handleClientFrame processes an inbound WebSocket text frame. Currently this is
// the typing signal, which is relayed to the conversation's other members.
func (h *ChatHandler) handleClientFrame(userID int64, data []byte) {
	var f struct {
		Type           string `json:"type"`
		ConversationID int64  `json:"conversation_id"`
		FromName       string `json:"from_name"`
	}
	if json.Unmarshal(data, &f) != nil || f.Type != "typing" {
		return
	}
	ctx := context.Background()
	ids, err := h.q.ConversationMemberIDs(ctx, f.ConversationID)
	if err != nil {
		return
	}
	isMember := false
	others := make([]int64, 0, len(ids))
	for _, id := range ids {
		if id == userID {
			isMember = true
		} else {
			others = append(others, id)
		}
	}
	if !isMember || len(others) == 0 {
		return
	}
	payload, err := json.Marshal(map[string]any{
		"type":            "typing",
		"conversation_id": f.ConversationID,
		"from_id":         userID,
		"from_name":       f.FromName,
	})
	if err != nil {
		return
	}
	h.hub.SendToUsers(others, payload)
}

// handlePresence broadcasts a user's online/offline transition to everyone.
func (h *ChatHandler) handlePresence(userID int64, online bool) {
	payload, err := json.Marshal(map[string]any{
		"type":    "presence",
		"user_id": userID,
		"online":  online,
	})
	if err != nil {
		return
	}
	h.hub.broadcastAll(payload)
}

// presence returns the ids of users currently connected to the chat socket.
func (h *ChatHandler) presence(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK,
		map[string][]int64{"online": h.hub.OnlineUserIDs()})
}

// deleteMessage removes a message (its sender, or a conversation admin) and
// tells the other members so they can drop it live.
func (h *ChatHandler) deleteMessage(w http.ResponseWriter, r *http.Request) {
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
	msg, err := h.q.GetMessageWithSender(r.Context(), mid)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("message not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	role, member := h.memberRole(r.Context(), msg.ConversationID, actor)
	if !member {
		writeError(w, http.StatusForbidden, errors.New("not a member of this conversation"))
		return
	}
	isSender := msg.SenderID != nil && *msg.SenderID == actor
	if !isSender && role != "admin" {
		writeError(w, http.StatusForbidden,
			errors.New("only the sender or an admin can delete this message"))
		return
	}
	if err := h.q.DeleteMessage(r.Context(), mid); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if msg.AttachmentStored != "" {
		_ = os.Remove(filepath.Join(h.dir, msg.AttachmentStored))
	}
	if ids, e := h.q.ConversationMemberIDs(r.Context(), msg.ConversationID); e == nil {
		if payload, me := json.Marshal(map[string]any{
			"type":            "message_deleted",
			"conversation_id": msg.ConversationID,
			"id":              mid,
		}); me == nil {
			h.hub.SendToUsers(ids, payload)
		}
	}
	w.WriteHeader(http.StatusNoContent)
}
