package handler

import (
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/livekit/protocol/livekit"
	lksdk "github.com/livekit/server-sdk-go/v2"
)

// CallModHandler serves /api/v1/calls — host (admin) moderation of a live call.
// These actions are privileged and run server-side via the LiveKit RoomService
// API; a participant can't mute or remove another from the browser.
type CallModHandler struct {
	rs *lksdk.RoomServiceClient
}

// NewCallModHandler builds the moderation handler. When LiveKit isn't
// configured the endpoints report that calls are unavailable.
func NewCallModHandler(cfg LiveKitConfig) *CallModHandler {
	if cfg.APIKey == "" || cfg.APISecret == "" {
		return &CallModHandler{}
	}
	host := strings.Replace(cfg.URL, "wss://", "https://", 1)
	host = strings.Replace(host, "ws://", "http://", 1)
	return &CallModHandler{
		rs: lksdk.NewRoomServiceClient(host, cfg.APIKey, cfg.APISecret),
	}
}

// Routes builds the sub-router mounted at /api/v1/calls. All actions require an
// admin (the call host).
func (h *CallModHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Post("/mute", h.mute)
	r.Post("/remove", h.remove)
	r.Post("/permissions", h.permissions)
	return r
}

func (h *CallModHandler) ready(w http.ResponseWriter, r *http.Request) bool {
	if h.rs == nil {
		writeError(w, http.StatusServiceUnavailable,
			errors.New("calls are not configured"))
		return false
	}
	return requireAdmin(w, r)
}

func (h *CallModHandler) mute(w http.ResponseWriter, r *http.Request) {
	if !h.ready(w, r) {
		return
	}
	var b struct {
		Room     string `json:"room"`
		Identity string `json:"identity"`
		TrackSid string `json:"track_sid"`
		Muted    bool   `json:"muted"`
	}
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Room == "" || b.Identity == "" {
		writeError(w, http.StatusBadRequest,
			errors.New("room and identity are required"))
		return
	}
	_, err := h.rs.MutePublishedTrack(r.Context(), &livekit.MuteRoomTrackRequest{
		Room:     b.Room,
		Identity: b.Identity,
		TrackSid: b.TrackSid,
		Muted:    b.Muted,
	})
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *CallModHandler) remove(w http.ResponseWriter, r *http.Request) {
	if !h.ready(w, r) {
		return
	}
	var b struct {
		Room     string `json:"room"`
		Identity string `json:"identity"`
	}
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Room == "" || b.Identity == "" {
		writeError(w, http.StatusBadRequest,
			errors.New("room and identity are required"))
		return
	}
	_, err := h.rs.RemoveParticipant(r.Context(), &livekit.RoomParticipantIdentity{
		Room:     b.Room,
		Identity: b.Identity,
	})
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// permissions toggles a participant's ability to publish (camera / mic /
// screen). Subscribing and data remain enabled so they can still watch.
func (h *CallModHandler) permissions(w http.ResponseWriter, r *http.Request) {
	if !h.ready(w, r) {
		return
	}
	var b struct {
		Room       string `json:"room"`
		Identity   string `json:"identity"`
		CanPublish bool   `json:"can_publish"`
	}
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Room == "" || b.Identity == "" {
		writeError(w, http.StatusBadRequest,
			errors.New("room and identity are required"))
		return
	}
	_, err := h.rs.UpdateParticipant(r.Context(), &livekit.UpdateParticipantRequest{
		Room:     b.Room,
		Identity: b.Identity,
		Permission: &livekit.ParticipantPermission{
			CanPublish:     b.CanPublish,
			CanSubscribe:   true,
			CanPublishData: true,
		},
	})
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}
