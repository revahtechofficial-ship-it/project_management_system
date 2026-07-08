package handler

import (
	"errors"
	"net/http"
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
	return r
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
