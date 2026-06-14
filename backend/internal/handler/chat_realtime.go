package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
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

type userStatusResponse struct {
	UserID        int64      `json:"user_id"`
	Online        bool       `json:"online"`
	Status        string     `json:"status"`
	StatusMessage string     `json:"status_message"`
	LastSeenAt    *time.Time `json:"last_seen_at"`
}

var validStatuses = map[string]bool{
	"active": true, "away": true, "busy": true, "dnd": true,
}

// handlePresence records last-seen on disconnect and broadcasts the user's
// online/offline transition (with their chosen status) to everyone.
func (h *ChatHandler) handlePresence(userID int64, online bool) {
	ctx := context.Background()
	if !online {
		_ = h.q.SetLastSeen(ctx, userID)
	}
	status, message := "active", ""
	var lastSeen *time.Time
	if u, err := h.q.GetUserByID(ctx, userID); err == nil {
		status = u.Status
		message = u.StatusMessage
		lastSeen = tsPtr(u.LastSeenAt)
	}
	payload, err := json.Marshal(map[string]any{
		"type":           "status",
		"user_id":        userID,
		"online":         online,
		"status":         status,
		"status_message": message,
		"last_seen_at":   lastSeen,
	})
	if err != nil {
		return
	}
	h.hub.broadcastAll(payload)
}

// presence returns every user's status, with an online flag derived from live
// socket connections.
func (h *ChatHandler) presence(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListUserStatuses(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	onlineSet := make(map[int64]bool)
	for _, id := range h.hub.OnlineUserIDs() {
		onlineSet[id] = true
	}
	out := make([]userStatusResponse, 0, len(rows))
	for _, u := range rows {
		out = append(out, userStatusResponse{
			UserID:        u.ID,
			Online:        onlineSet[u.ID],
			Status:        u.Status,
			StatusMessage: u.StatusMessage,
			LastSeenAt:    tsPtr(u.LastSeenAt),
		})
	}
	writeJSON(w, http.StatusOK, out)
}

// setMyStatus updates the caller's manual status (active/away/busy/dnd) and
// optional custom message, then broadcasts it.
func (h *ChatHandler) setMyStatus(w http.ResponseWriter, r *http.Request) {
	actor, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b struct {
		Status        string `json:"status"`
		StatusMessage string `json:"status_message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	status := b.Status
	if !validStatuses[status] {
		status = "active"
	}
	message := strings.TrimSpace(b.StatusMessage)
	if err := h.q.SetUserStatus(r.Context(), db.SetUserStatusParams{
		ID: actor, Status: status, StatusMessage: message,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	now := time.Now().UTC()
	if payload, e := json.Marshal(map[string]any{
		"type":           "status",
		"user_id":        actor,
		"online":         true,
		"status":         status,
		"status_message": message,
		"last_seen_at":   now,
	}); e == nil {
		h.hub.broadcastAll(payload)
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"status": status, "status_message": message,
	})
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
