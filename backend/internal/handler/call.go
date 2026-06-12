package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type callTokenBody struct {
	Mode string `json:"mode"` // "audio" | "video"
	Ring bool   `json:"ring"` // true for the caller (rings other members)
}

type callTokenResponse struct {
	Token string `json:"token"`
	URL   string `json:"url"`
	Room  string `json:"room"`
	Mode  string `json:"mode"`
}

// callToken issues a LiveKit join token for the conversation's call room. When
// ring is set (the caller), it also pushes an incoming-call event to the other
// members over the chat WebSocket.
func (h *ChatHandler) callToken(w http.ResponseWriter, r *http.Request) {
	convID, actor, ok := h.authConv(w, r)
	if !ok {
		return
	}
	if h.lk.APIKey == "" || h.lk.APISecret == "" {
		writeError(w, http.StatusServiceUnavailable, errors.New("calls are not configured"))
		return
	}
	var b callTokenBody
	_ = json.NewDecoder(r.Body).Decode(&b) // body is optional
	mode := b.Mode
	if mode != "audio" && mode != "video" {
		mode = "video"
	}

	room := fmt.Sprintf("conv-%d", convID)
	name := "Member"
	if u, err := h.q.GetUserByID(r.Context(), actor); err == nil && u.FullName != "" {
		name = u.FullName
	}
	token, err := h.livekitToken(room, strconv.FormatInt(actor, 10), name)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if b.Ring {
		h.broadcastCall(r.Context(), convID, room, mode, actor, name)
	}
	writeJSON(w, http.StatusOK, callTokenResponse{
		Token: token, URL: h.lk.URL, Room: room, Mode: mode,
	})
}

// livekitToken builds a LiveKit access token: an HS256 JWT whose issuer is the
// API key and whose `video` grant authorizes joining the given room. This is
// the exact shape the LiveKit server validates, so no SDK is needed.
func (h *ChatHandler) livekitToken(room, identity, name string) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"iss":  h.lk.APIKey,
		"sub":  identity,
		"name": name,
		"nbf":  now.Add(-10 * time.Second).Unix(),
		"exp":  now.Add(2 * time.Hour).Unix(),
		"video": map[string]any{
			"room":         room,
			"roomJoin":     true,
			"canPublish":   true,
			"canSubscribe": true,
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).
		SignedString([]byte(h.lk.APISecret))
}

func (h *ChatHandler) broadcastCall(ctx context.Context, convID int64,
	room, mode string, fromID int64, fromName string) {
	ids, err := h.q.ConversationMemberIDs(ctx, convID)
	if err != nil {
		return
	}
	payload, err := json.Marshal(map[string]any{
		"type":            "call",
		"conversation_id": convID,
		"room":            room,
		"mode":            mode,
		"from_id":         fromID,
		"from_name":       fromName,
	})
	if err != nil {
		return
	}
	h.hub.SendToUsers(ids, payload)
}
