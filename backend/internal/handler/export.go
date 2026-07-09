package handler

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// AccountDataHandler serves /api/v1/account — a GDPR-style export of the
// authenticated user's own data.
type AccountDataHandler struct {
	q *db.Queries
}

// NewAccountDataHandler wires the handler to the query layer.
func NewAccountDataHandler(q *db.Queries) *AccountDataHandler {
	return &AccountDataHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/account.
func (h *AccountDataHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/export", h.export)
	r.Get("/notification-prefs", h.getNotificationPrefs)
	r.Put("/notification-prefs", h.setNotificationPrefs)
	return r
}

// getNotificationPrefs returns the user's per-category notification channel
// preferences as a JSON object ({} when none are set).
func (h *AccountDataHandler) getNotificationPrefs(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	user, err := h.q.GetUserByID(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	raw := json.RawMessage(user.NotificationPrefs)
	if len(strings.TrimSpace(user.NotificationPrefs)) == 0 {
		raw = json.RawMessage("{}")
	}
	writeJSON(w, http.StatusOK, raw)
}

// setNotificationPrefs stores the user's notification preferences (a JSON
// object of category -> {in_app, email}).
func (h *AccountDataHandler) setNotificationPrefs(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<16))
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	var probe map[string]any
	if err := json.Unmarshal(body, &probe); err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid preferences"))
		return
	}
	if err := h.q.SetUserNotificationPrefs(r.Context(),
		db.SetUserNotificationPrefsParams{ID: *actor, Prefs: string(body)}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// export returns the authenticated user's personal data as one JSON document.
// Secrets (password hash, calendar/feed tokens) are never included.
func (h *AccountDataHandler) export(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	uid := *actor
	user, err := h.q.GetUserByID(r.Context(), uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	profile := map[string]any{
		"id":                  user.ID,
		"email":               user.Email,
		"full_name":           user.FullName,
		"role":                user.Role,
		"phone":               user.Phone,
		"job_title":           user.JobTitle,
		"department":          user.Department,
		"location":            user.Location,
		"bio":                 user.Bio,
		"status":              user.Status,
		"email_verified":      user.EmailVerified,
		"two_factor_enabled":  user.TwoFactorEnabled,
		"email_notifications": user.EmailNotifications,
		"created_at":          user.CreatedAt.Format(time.RFC3339),
	}

	notifications, _ := h.q.ListNotifications(r.Context(), &uid)
	approvals, _ := h.q.ListMyApprovalRequests(r.Context(), uid)
	leave, _ := h.q.ListMyLeave(r.Context(), uid)
	oneOnOnes, _ := h.q.ListMyOneOnOnes(r.Context(), uid)
	skills, _ := h.q.ListMySkills(r.Context(), uid)
	tasks, _ := h.q.ListMyDueTasks(r.Context(), uid)

	writeJSON(w, http.StatusOK, map[string]any{
		"exported_at":    time.Now().Format(time.RFC3339),
		"profile":        profile,
		"notifications":  notifications,
		"approvals":      approvals,
		"leave":          leave,
		"one_on_ones":    oneOnOnes,
		"skills":         skills,
		"upcoming_tasks": tasks,
	})
}
