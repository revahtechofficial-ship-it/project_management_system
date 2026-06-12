package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// LiveKitConfig holds the settings the chat handler needs to mint LiveKit join
// tokens and tell clients where to connect.
type LiveKitConfig struct {
	URL       string
	APIKey    string
	APISecret string
}

// ChatHandler serves the /api/v1/chat resource plus the chat WebSocket. It owns
// the shared Hub used to push real-time message events to connected clients.
type ChatHandler struct {
	q   *db.Queries
	dir string
	hub *Hub
	lk  LiveKitConfig
}

// NewChatHandler wires the handler to the query layer, attachment directory,
// real-time hub and LiveKit (calls) configuration.
func NewChatHandler(q *db.Queries, dir string, hub *Hub, lk LiveKitConfig) *ChatHandler {
	h := &ChatHandler{q: q, dir: dir, hub: hub, lk: lk}
	hub.SetPresenceHandler(h.handlePresence)
	return h
}

var chatUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	// Auth is enforced via the token query param, so any origin may upgrade.
	CheckOrigin: func(r *http.Request) bool { return true },
}

// Routes builds the REST sub-router mounted under /api/v1/chat.
func (h *ChatHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/conversations", h.listConversations)
	r.Post("/conversations", h.createConversation)
	r.Get("/conversations/{id}/messages", h.listMessages)
	r.Post("/conversations/{id}/messages", h.sendMessage)
	r.Post("/conversations/{id}/upload", h.uploadMessage)
	r.Post("/conversations/{id}/read", h.markRead)
	r.Patch("/conversations/{id}", h.rename)
	r.Get("/conversations/{id}/members", h.listMembers)
	r.Post("/conversations/{id}/members", h.addMembers)
	r.Delete("/conversations/{id}/members/{userId}", h.removeMember)
	r.Post("/conversations/{id}/call-token", h.callToken)
	r.Delete("/messages/{messageId}", h.deleteMessage)
	r.Patch("/messages/{messageId}", h.editMessage)
	r.Post("/messages/{messageId}/reactions", h.toggleReaction)
	r.Get("/conversations/{id}/reactions", h.listReactions)
	r.Get("/presence", h.presence)
	return r
}

// --- response shapes -------------------------------------------------------

type conversationResponse struct {
	ID           int64     `json:"id"`
	Type         string    `json:"type"`
	Name         string    `json:"name"`
	OtherUserID  *int64    `json:"other_user_id"`
	UnreadCount  int32     `json:"unread_count"`
	LastBody     string    `json:"last_body"`
	LastKind     string    `json:"last_kind"`
	LastAt       time.Time `json:"last_at"`
	LastSenderID *int64    `json:"last_sender_id"`
	CreatedAt    time.Time `json:"created_at"`
}

type messageResponse struct {
	ID             int64     `json:"id"`
	ConversationID int64     `json:"conversation_id"`
	SenderID       *int64    `json:"sender_id"`
	SenderName     *string   `json:"sender_name"`
	Kind           string    `json:"kind"`
	Body           string    `json:"body"`
	Edited         bool      `json:"edited"`
	AttachmentName string    `json:"attachment_name"`
	AttachmentType string    `json:"attachment_type"`
	AttachmentSize int64     `json:"attachment_size"`
	CreatedAt      time.Time `json:"created_at"`
}

type memberResponse struct {
	UserID   int64  `json:"user_id"`
	Role     string `json:"role"`
	FullName string `json:"full_name"`
	Email    string `json:"email"`
}

func conversationFromRow(r db.ListConversationsForUserRow) conversationResponse {
	title := r.Name
	var otherID *int64
	if r.Type == "dm" {
		title = r.OtherUserName
		if r.OtherUserID != 0 {
			id := r.OtherUserID
			otherID = &id
		}
	}
	return conversationResponse{
		ID:           r.ID,
		Type:         r.Type,
		Name:         title,
		OtherUserID:  otherID,
		UnreadCount:  r.UnreadCount,
		LastBody:     r.LastBody,
		LastKind:     r.LastKind,
		LastAt:       r.LastAt,
		LastSenderID: r.LastSenderID,
		CreatedAt:    r.CreatedAt,
	}
}

func messageFromGet(r db.GetMessageWithSenderRow) messageResponse {
	return messageResponse{
		ID:             r.ID,
		ConversationID: r.ConversationID,
		SenderID:       r.SenderID,
		SenderName:     r.SenderName,
		Kind:           r.Kind,
		Body:           r.Body,
		Edited:         r.Edited,
		AttachmentName: r.AttachmentName,
		AttachmentType: r.AttachmentType,
		AttachmentSize: r.AttachmentSize,
		CreatedAt:      r.CreatedAt,
	}
}

func messageFromList(r db.ListMessagesRow) messageResponse {
	return messageResponse{
		ID:             r.ID,
		ConversationID: r.ConversationID,
		SenderID:       r.SenderID,
		SenderName:     r.SenderName,
		Kind:           r.Kind,
		Body:           r.Body,
		Edited:         r.Edited,
		AttachmentName: r.AttachmentName,
		AttachmentType: r.AttachmentType,
		AttachmentSize: r.AttachmentSize,
		CreatedAt:      r.CreatedAt,
	}
}

// --- helpers ---------------------------------------------------------------

func chatActor(ctx context.Context) (int64, bool) {
	if c, ok := account.FromContext(ctx); ok {
		return c.UserID, true
	}
	return 0, false
}

// memberRole returns the actor's role in a conversation, and whether they are a
// member at all.
func (h *ChatHandler) memberRole(ctx context.Context, convID, userID int64) (string, bool) {
	role, err := h.q.GetConversationMemberRole(ctx, db.GetConversationMemberRoleParams{
		ConversationID: convID,
		UserID:         userID,
	})
	if err != nil {
		return "", false
	}
	return role, true
}

// broadcastMessage pushes a new message event to every member of the
// conversation that has a live WebSocket connection.
func (h *ChatHandler) broadcastMessage(ctx context.Context, convID int64, msg messageResponse) {
	ids, err := h.q.ConversationMemberIDs(ctx, convID)
	if err != nil {
		return
	}
	payload, err := json.Marshal(map[string]any{
		"type":            "message",
		"conversation_id": convID,
		"message":         msg,
	})
	if err != nil {
		return
	}
	h.hub.SendToUsers(ids, payload)
}

// --- conversations ---------------------------------------------------------

func (h *ChatHandler) listConversations(w http.ResponseWriter, r *http.Request) {
	uid, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	rows, err := h.q.ListConversationsForUser(r.Context(), &uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]conversationResponse, 0, len(rows))
	for _, row := range rows {
		out = append(out, conversationFromRow(row))
	}
	writeJSON(w, http.StatusOK, out)
}

type createConvBody struct {
	Type      string  `json:"type"`
	Name      string  `json:"name"`
	MemberIDs []int64 `json:"member_ids"`
}

func (h *ChatHandler) createConversation(w http.ResponseWriter, r *http.Request) {
	actor, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b createConvBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	ctx := r.Context()

	if b.Type == "dm" {
		if len(b.MemberIDs) == 0 || b.MemberIDs[0] == actor {
			writeError(w, http.StatusBadRequest, errors.New("a different user is required for a direct message"))
			return
		}
		other := b.MemberIDs[0]
		existing, err := h.q.FindDMConversation(ctx, db.FindDMConversationParams{UserA: actor, UserB: other})
		if err == nil {
			writeJSON(w, http.StatusOK, map[string]int64{"id": existing})
			return
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		conv, err := h.q.CreateConversation(ctx, db.CreateConversationParams{
			Type: "dm", Name: "", CreatedBy: &actor,
		})
		if err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		h.addMember(ctx, conv.ID, actor, "member")
		h.addMember(ctx, conv.ID, other, "member")
		writeJSON(w, http.StatusCreated, map[string]int64{"id": conv.ID})
		return
	}

	// Group conversation.
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a group name is required"))
		return
	}
	conv, err := h.q.CreateConversation(ctx, db.CreateConversationParams{
		Type: "group", Name: name, CreatedBy: &actor,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.addMember(ctx, conv.ID, actor, "admin")
	for _, m := range b.MemberIDs {
		if m != actor {
			h.addMember(ctx, conv.ID, m, "member")
		}
	}
	writeJSON(w, http.StatusCreated, map[string]int64{"id": conv.ID})
}

func (h *ChatHandler) addMember(ctx context.Context, convID, userID int64, role string) {
	_ = h.q.AddConversationMember(ctx, db.AddConversationMemberParams{
		ConversationID: convID, UserID: userID, Role: role,
	})
}

func (h *ChatHandler) rename(w http.ResponseWriter, r *http.Request) {
	convID, actor, ok := h.authConv(w, r)
	if !ok {
		return
	}
	var b struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	_ = actor
	if err := h.q.RenameConversation(r.Context(), db.RenameConversationParams{ID: convID, Name: name}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- messages --------------------------------------------------------------

func (h *ChatHandler) listMessages(w http.ResponseWriter, r *http.Request) {
	convID, _, ok := h.authConv(w, r)
	if !ok {
		return
	}
	limit := clampInt(parseIntDefault(r.URL.Query().Get("limit"), 30), 1, 100)
	offset := maxInt(parseIntDefault(r.URL.Query().Get("offset"), 0), 0)
	rows, err := h.q.ListMessages(r.Context(), db.ListMessagesParams{
		ConversationID: convID,
		Lim:            int32(limit),
		Off:            int32(offset),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]messageResponse, 0, len(rows))
	for _, row := range rows {
		out = append(out, messageFromList(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ChatHandler) sendMessage(w http.ResponseWriter, r *http.Request) {
	convID, actor, ok := h.authConv(w, r)
	if !ok {
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
	created, err := h.q.CreateMessage(r.Context(), db.CreateMessageParams{
		ConversationID: convID,
		SenderID:       &actor,
		Kind:           "text",
		Body:           body,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.finishMessage(w, r, convID, created.ID)
}

func (h *ChatHandler) uploadMessage(w http.ResponseWriter, r *http.Request) {
	convID, actor, ok := h.authConv(w, r)
	if !ok {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes)
	if err := r.ParseMultipartForm(maxUploadBytes); err != nil {
		writeError(w, http.StatusBadRequest, errors.New("file too large (max 25MB)"))
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("a file is required"))
		return
	}
	defer file.Close()

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
	size, copyErr := io.Copy(dst, file)
	closeErr := dst.Close()
	if copyErr != nil || closeErr != nil {
		writeError(w, http.StatusInternalServerError, errors.New("could not store file"))
		return
	}

	contentType := header.Header.Get("Content-Type")
	kind := "file"
	if strings.HasPrefix(contentType, "image/") {
		kind = "image"
	}
	created, err := h.q.CreateMessage(r.Context(), db.CreateMessageParams{
		ConversationID:   convID,
		SenderID:         &actor,
		Kind:             kind,
		Body:             strings.TrimSpace(r.FormValue("caption")),
		AttachmentName:   header.Filename,
		AttachmentStored: stored,
		AttachmentType:   contentType,
		AttachmentSize:   size,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.finishMessage(w, r, convID, created.ID)
}

// finishMessage loads the stored message with its sender name, responds with it
// and broadcasts it to the conversation's members.
func (h *ChatHandler) finishMessage(w http.ResponseWriter, r *http.Request, convID, msgID int64) {
	row, err := h.q.GetMessageWithSender(r.Context(), msgID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	mr := messageFromGet(row)
	h.broadcastMessage(r.Context(), convID, mr)
	writeJSON(w, http.StatusCreated, mr)
}

func (h *ChatHandler) markRead(w http.ResponseWriter, r *http.Request) {
	convID, actor, ok := h.authConv(w, r)
	if !ok {
		return
	}
	if err := h.q.MarkConversationRead(r.Context(), db.MarkConversationReadParams{
		ConversationID: convID, UserID: actor,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- members ---------------------------------------------------------------

func (h *ChatHandler) listMembers(w http.ResponseWriter, r *http.Request) {
	convID, _, ok := h.authConv(w, r)
	if !ok {
		return
	}
	rows, err := h.q.ListConversationMembers(r.Context(), convID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]memberResponse, 0, len(rows))
	for _, m := range rows {
		out = append(out, memberResponse{
			UserID:   m.UserID,
			Role:     m.Role,
			FullName: m.FullName,
			Email:    m.Email,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ChatHandler) addMembers(w http.ResponseWriter, r *http.Request) {
	convID, _, ok := h.authConv(w, r)
	if !ok {
		return
	}
	var b struct {
		UserIDs []int64 `json:"user_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	for _, uid := range b.UserIDs {
		h.addMember(r.Context(), convID, uid, "member")
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ChatHandler) removeMember(w http.ResponseWriter, r *http.Request) {
	convID, actor, ok := h.authConv(w, r)
	if !ok {
		return
	}
	target, err := strconv.ParseInt(chi.URLParam(r, "userId"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid user id"))
		return
	}
	// Members may remove themselves; removing others requires the admin role.
	if target != actor {
		if role, _ := h.memberRole(r.Context(), convID, actor); role != "admin" {
			writeError(w, http.StatusForbidden, errors.New("only an admin can remove other members"))
			return
		}
	}
	if err := h.q.RemoveConversationMember(r.Context(), db.RemoveConversationMemberParams{
		ConversationID: convID, UserID: target,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// authConv resolves the {id} conversation, confirms the caller is a member, and
// returns the conversation id and actor id. It writes the error response and
// returns ok=false when the caller is not authorized.
func (h *ChatHandler) authConv(w http.ResponseWriter, r *http.Request) (int64, int64, bool) {
	actor, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return 0, 0, false
	}
	convID, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return 0, 0, false
	}
	if _, member := h.memberRole(r.Context(), convID, actor); !member {
		writeError(w, http.StatusForbidden, errors.New("not a member of this conversation"))
		return 0, 0, false
	}
	return convID, actor, true
}

// --- media download + websocket -------------------------------------------

// Download streams a message attachment. The token is accepted via query param
// (so a plain browser navigation can fetch it).
func (h *ChatHandler) Download(w http.ResponseWriter, r *http.Request) {
	actor, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	msg, err := h.q.GetMessageWithSender(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && msg.AttachmentStored == "") {
		writeError(w, http.StatusNotFound, errors.New("attachment not found"))
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
	if msg.AttachmentType != "" {
		w.Header().Set("Content-Type", msg.AttachmentType)
	}
	w.Header().Set("Content-Disposition",
		fmt.Sprintf("inline; filename=%q", msg.AttachmentName))
	http.ServeFile(w, r, filepath.Join(h.dir, msg.AttachmentStored))
}

// WS upgrades the connection and registers it with the hub for the duration of
// the session.
func (h *ChatHandler) WS(w http.ResponseWriter, r *http.Request) {
	actor, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	conn, err := chatUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	client := &wsConn{
		hub:    h.hub,
		conn:   conn,
		userID: actor,
		send:   make(chan []byte, wsSendBuffer),
		onText: h.handleClientFrame,
	}
	h.hub.register(client)
	go client.writePump()
	go client.readPump()
}
