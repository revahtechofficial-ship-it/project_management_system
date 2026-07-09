package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// notifier sends a notification email. Satisfied by *email.Sender.
type notifier interface {
	Notify(to, title, body string) error
}

// notifyMailer is the process-wide mailer used to also deliver notifications by
// email. Set once at startup via SetNotifyMailer; nil disables email delivery.
var notifyMailer notifier

// SetNotifyMailer wires the mailer used to email in-app notifications.
func SetNotifyMailer(m notifier) { notifyMailer = m }

// deliverable guards against sending to obviously-undeliverable addresses
// (empty, or example/test/localhost domains), so notification email never
// bounces off placeholder test accounts.
func deliverable(email string) bool {
	e := strings.ToLower(strings.TrimSpace(email))
	if e == "" || !strings.Contains(e, "@") {
		return false
	}
	for _, bad := range []string{
		"@example.com", "@example.org", "@example.net",
		"@test.", "@localhost", "@invalid", ".test", ".local",
	} {
		if strings.Contains(e, bad) {
			return false
		}
	}
	return true
}

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

type channelPref struct {
	InApp *bool `json:"in_app"`
	Email *bool `json:"email"`
}

// notifCategory groups a notification type into a user-facing preference
// category. Unknown types fall back to "tasks".
func notifCategory(typ string) string {
	switch typ {
	case "assigned":
		return "assignments"
	case "approval":
		return "approvals"
	case "comment", "mention":
		return "comments"
	case "incident":
		return "incidents"
	case "expense":
		return "finance"
	case "leave", "one_on_one", "timesheet":
		return "hr"
	default:
		return "tasks"
	}
}

// channelPrefs resolves whether in-app and email delivery are enabled for an
// event type from a user's stored preferences JSON. Both default to true so a
// user with no preferences (or an unknown category) still gets everything.
func channelPrefs(rawJSON, typ string) (inApp bool, email bool) {
	inApp, email = true, true
	prefs := map[string]channelPref{}
	if json.Unmarshal([]byte(rawJSON), &prefs) != nil {
		return
	}
	if p, ok := prefs[notifCategory(typ)]; ok {
		if p.InApp != nil {
			inApp = *p.InApp
		}
		if p.Email != nil {
			email = *p.Email
		}
	}
	return
}

// notifyUser delivers an in-app notification to one recipient on a best-effort
// basis; failures are swallowed so they never break the triggering action.
// Recipients in Do Not Disturb mode are skipped, and per-user, per-category
// preferences decide which channels fire (defaulting to all on).
func notifyUser(ctx context.Context, q *db.Queries, userID int64,
	typ, title, body, link string) {
	user, err := q.GetUserByID(ctx, userID)
	if err == nil && user.Status == "dnd" {
		return
	}
	inApp, emailPref := true, true
	if err == nil {
		inApp, emailPref = channelPrefs(user.NotificationPrefs, typ)
	}
	if inApp {
		uid := userID
		_, _ = q.CreateNotification(ctx, db.CreateNotificationParams{
			UserID: &uid,
			Type:   typ,
			Title:  title,
			Body:   body,
			Link:   link,
		})
	}
	// Also deliver by email when enabled for this category, the recipient opted
	// in globally and the address looks deliverable. Best-effort and off the
	// request path so it never blocks.
	if err == nil && emailPref && user.EmailNotifications && notifyMailer != nil &&
		deliverable(user.Email) {
		to, subject, msg := user.Email, title, body
		go func() { _ = notifyMailer.Notify(to, subject, msg) }()
	}
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
	notifyUser(ctx, q, *assignee, "assigned", "You were assigned a task", title, "/tasks")
}
