package handler

import (
	"context"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// NotificationHandler serves the /api/v1/notifications resource. Every endpoint
// is scoped to the authenticated user — notifications are per-recipient.
type NotificationHandler struct {
	q *db.Queries
}

// NewNotificationHandler wires the handler to the generated query layer.
func NewNotificationHandler(q *db.Queries) *NotificationHandler {
	return &NotificationHandler{q: q}
}

// Routes builds a sub-router intended to be mounted under
// /api/v1/notifications.
func (h *NotificationHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Get("/unread-count", h.unreadCount)
	r.Post("/read-all", h.readAll)
	r.Patch("/{id}/read", h.markRead)
	return r
}

func (h *NotificationHandler) list(w http.ResponseWriter, r *http.Request) {
	uid, ok := recipientOf(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	items, err := h.q.ListNotifications(r.Context(), uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *NotificationHandler) unreadCount(w http.ResponseWriter, r *http.Request) {
	uid, ok := recipientOf(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	n, err := h.q.CountUnreadNotifications(r.Context(), uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int64{"count": n})
}

func (h *NotificationHandler) readAll(w http.ResponseWriter, r *http.Request) {
	uid, ok := recipientOf(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	if err := h.q.MarkAllNotificationsRead(r.Context(), uid); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *NotificationHandler) markRead(w http.ResponseWriter, r *http.Request) {
	uid, ok := recipientOf(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.MarkNotificationRead(r.Context(), db.MarkNotificationReadParams{
		ID:     id,
		UserID: uid,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// recipientOf returns the authenticated user's id as the *int64 the generated
// queries expect (nil when there is no authenticated user).
func recipientOf(ctx context.Context) (*int64, bool) {
	if c, ok := account.FromContext(ctx); ok {
		id := c.UserID
		return &id, true
	}
	return nil, false
}

// notifyUser delivers an in-app notification to one recipient on a best-effort
// basis; failures are swallowed so they never break the triggering action.
// Recipients in Do Not Disturb mode are skipped.
func notifyUser(ctx context.Context, q *db.Queries, userID int64,
	typ, title, body string) {
	if u, err := q.GetUserByID(ctx, userID); err == nil && u.Status == "dnd" {
		return
	}
	uid := userID
	_, _ = q.CreateNotification(ctx, db.CreateNotificationParams{
		UserID: &uid,
		Type:   typ,
		Title:  title,
		Body:   body,
	})
}

// notifyAssigned tells a task's assignee they were given the task, skipping the
// no-op case where the assignee is the person who made the change.
func notifyAssigned(ctx context.Context, q *db.Queries, assignee *int64,
	title string) {
	if assignee == nil {
		return
	}
	if actor := actorOf(ctx); actor != nil && *actor == *assignee {
		return
	}
	notifyUser(ctx, q, *assignee, "assigned", "You were assigned a task", title)
}
