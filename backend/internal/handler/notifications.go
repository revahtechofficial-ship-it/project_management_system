package handler

import (
	"context"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// NotificationHandler serves the /api/v1/notifications resource.
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
	items, err := h.q.ListNotifications(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *NotificationHandler) unreadCount(w http.ResponseWriter, r *http.Request) {
	n, err := h.q.CountUnreadNotifications(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int64{"count": n})
}

func (h *NotificationHandler) readAll(w http.ResponseWriter, r *http.Request) {
	if err := h.q.MarkAllNotificationsRead(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *NotificationHandler) markRead(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.MarkNotificationRead(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// notify creates a workspace notification on a best-effort basis; failures are
// swallowed so they never break the action that triggered them.
func notify(ctx context.Context, q *db.Queries, typ, title, body string) {
	_, _ = q.CreateNotification(ctx, db.CreateNotificationParams{
		Type:  typ,
		Title: title,
		Body:  body,
	})
}
