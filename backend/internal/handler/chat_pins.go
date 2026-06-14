package handler

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// listPinned returns a conversation's pinned messages, newest first.
func (h *ChatHandler) listPinned(w http.ResponseWriter, r *http.Request) {
	convID, _, ok := h.authConv(w, r)
	if !ok {
		return
	}
	rows, err := h.q.ListPinnedMessages(r.Context(), convID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]messageResponse, 0, len(rows))
	for _, row := range rows {
		out = append(out, messageFromPinned(row))
	}
	writeJSON(w, http.StatusOK, out)
}

// setPin pins or unpins a message and broadcasts the change.
func (h *ChatHandler) setPin(w http.ResponseWriter, r *http.Request) {
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
		Pinned bool `json:"pinned"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
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
	if err := h.q.SetMessagePinned(r.Context(), db.SetMessagePinnedParams{
		ID: mid, Pinned: b.Pinned,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if ids, e := h.q.ConversationMemberIDs(r.Context(), msg.ConversationID); e == nil {
		if payload, me := json.Marshal(map[string]any{
			"type":            "pin",
			"conversation_id": msg.ConversationID,
			"message_id":      mid,
			"pinned":          b.Pinned,
		}); me == nil {
			h.hub.SendToUsers(ids, payload)
		}
	}
	w.WriteHeader(http.StatusNoContent)
}

// forwardMessage copies a message (and any attachment) into another
// conversation the caller belongs to, flagged as forwarded.
func (h *ChatHandler) forwardMessage(w http.ResponseWriter, r *http.Request) {
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
		ConversationID int64 `json:"conversation_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	src, err := h.q.GetMessageWithSender(r.Context(), mid)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("message not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if _, member := h.memberRole(r.Context(), src.ConversationID, actor); !member {
		writeError(w, http.StatusForbidden, errors.New("not a member of the source conversation"))
		return
	}
	if _, member := h.memberRole(r.Context(), b.ConversationID, actor); !member {
		writeError(w, http.StatusForbidden, errors.New("not a member of the target conversation"))
		return
	}

	// Duplicate the attachment file so deleting either copy is independent.
	stored := ""
	if src.AttachmentStored != "" {
		stored = h.copyStoredFile(src.AttachmentStored)
	}
	created, err := h.q.CreateMessage(r.Context(), db.CreateMessageParams{
		ConversationID:   b.ConversationID,
		SenderID:         &actor,
		Kind:             src.Kind,
		Body:             src.Body,
		AttachmentName:   src.AttachmentName,
		AttachmentStored: stored,
		AttachmentType:   src.AttachmentType,
		AttachmentSize:   src.AttachmentSize,
		Forwarded:        true,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.finishMessage(w, r, b.ConversationID, created.ID)
}

// uploadConversationAvatar stores a group conversation's photo (any member may
// set it) and returns its public URL.
func (h *ChatHandler) uploadConversationAvatar(w http.ResponseWriter, r *http.Request) {
	convID, _, ok := h.authConv(w, r)
	if !ok {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes)
	if err := r.ParseMultipartForm(maxUploadMemory); err != nil {
		writeError(w, http.StatusBadRequest, errors.New("file too large (max 100MB)"))
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("an image file is required"))
		return
	}
	defer file.Close()
	if !strings.HasPrefix(header.Header.Get("Content-Type"), "image/") {
		writeError(w, http.StatusBadRequest, errors.New("only image files are allowed"))
		return
	}
	if err := os.MkdirAll(h.dir, 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	stored := randomHex(16) + filepath.Ext(header.Filename)
	dst, err := os.Create(filepath.Join(h.dir, stored))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	_, copyErr := io.Copy(dst, file)
	closeErr := dst.Close()
	if copyErr != nil || closeErr != nil {
		writeError(w, http.StatusInternalServerError, errors.New("could not store image"))
		return
	}
	if err := h.q.SetConversationAvatar(r.Context(), db.SetConversationAvatarParams{
		ID: convID, Avatar: stored,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"group_avatar_url": avatarURLPtr(stored),
	})
}

// copyStoredFile copies an on-disk attachment to a new random name and returns
// it (empty string on failure).
func (h *ChatHandler) copyStoredFile(name string) string {
	src, err := os.Open(filepath.Join(h.dir, name))
	if err != nil {
		return ""
	}
	defer src.Close()
	dstName := randomHex(16) + filepath.Ext(name)
	dst, err := os.Create(filepath.Join(h.dir, dstName))
	if err != nil {
		return ""
	}
	if _, err := io.Copy(dst, src); err != nil {
		_ = dst.Close()
		return ""
	}
	if err := dst.Close(); err != nil {
		return ""
	}
	return dstName
}
