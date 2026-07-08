package handler

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// DigestHandler serves /api/v1/digest — a personal summary of unread
// notifications and tasks due soon or overdue, viewable in-app and emailable
// to yourself on demand.
type DigestHandler struct {
	q *db.Queries
}

// NewDigestHandler wires the handler to the query layer.
func NewDigestHandler(q *db.Queries) *DigestHandler {
	return &DigestHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/digest.
func (h *DigestHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.get)
	r.Post("/email", h.email)
	return r
}

type digestTask struct {
	ID      int64     `json:"id"`
	Title   string    `json:"title"`
	Status  string    `json:"status"`
	DueDate time.Time `json:"due_date"`
}

type digestNotification struct {
	ID        int64     `json:"id"`
	Type      string    `json:"type"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	Link      string    `json:"link"`
	CreatedAt time.Time `json:"created_at"`
}

type digestResponse struct {
	UnreadCount   int64                `json:"unread_count"`
	Notifications []digestNotification `json:"notifications"`
	Overdue       []digestTask         `json:"overdue"`
	Upcoming      []digestTask         `json:"upcoming"`
}

// build assembles the digest for one user: unread notifications, overdue tasks
// and tasks due within the next week.
func (h *DigestHandler) build(ctx context.Context, uid int64) (digestResponse, error) {
	out := digestResponse{
		Notifications: []digestNotification{},
		Overdue:       []digestTask{},
		Upcoming:      []digestTask{},
	}
	id := uid
	count, err := h.q.CountUnreadNotifications(ctx, &id)
	if err != nil {
		return out, err
	}
	out.UnreadCount = count
	notes, err := h.q.ListUnreadNotificationsDigest(ctx, &id)
	if err != nil {
		return out, err
	}
	for _, n := range notes {
		out.Notifications = append(out.Notifications, digestNotification{
			ID:        n.ID,
			Type:      n.Type,
			Title:     n.Title,
			Body:      n.Body,
			Link:      n.Link,
			CreatedAt: n.CreatedAt,
		})
	}
	tasks, err := h.q.ListMyDueTasks(ctx, uid)
	if err != nil {
		return out, err
	}
	now := time.Now()
	weekAhead := now.Add(7 * 24 * time.Hour)
	for _, t := range tasks {
		if !t.DueDate.Valid {
			continue
		}
		item := digestTask{
			ID:      t.ID,
			Title:   t.Title,
			Status:  t.Status,
			DueDate: t.DueDate.Time,
		}
		if t.DueDate.Time.Before(now) {
			out.Overdue = append(out.Overdue, item)
		} else if t.DueDate.Time.Before(weekAhead) {
			out.Upcoming = append(out.Upcoming, item)
		}
	}
	return out, nil
}

func (h *DigestHandler) get(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	d, err := h.build(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, d)
}

// digestEmailBody renders the digest as a plain-text email.
func digestEmailBody(name string, d digestResponse) string {
	var b strings.Builder
	if name != "" {
		fmt.Fprintf(&b, "Hi %s,\n\n", name)
	}
	b.WriteString("Here's your Revah digest.\n\n")
	fmt.Fprintf(&b, "Unread notifications: %d\n", d.UnreadCount)
	for _, n := range d.Notifications {
		fmt.Fprintf(&b, "  - %s\n", n.Title)
	}
	fmt.Fprintf(&b, "\nOverdue tasks (%d):\n", len(d.Overdue))
	for _, t := range d.Overdue {
		fmt.Fprintf(&b, "  - %s (due %s)\n", t.Title, t.DueDate.Format("Jan 2"))
	}
	fmt.Fprintf(&b, "\nDue this week (%d):\n", len(d.Upcoming))
	for _, t := range d.Upcoming {
		fmt.Fprintf(&b, "  - %s (due %s)\n", t.Title, t.DueDate.Format("Jan 2"))
	}
	return b.String()
}

func (h *DigestHandler) email(w http.ResponseWriter, r *http.Request) {
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
	if !user.EmailNotifications {
		writeJSON(w, http.StatusOK, map[string]any{
			"sent": false, "reason": "email notifications are turned off",
		})
		return
	}
	if notifyMailer == nil || !deliverable(user.Email) {
		writeJSON(w, http.StatusOK, map[string]any{
			"sent": false, "reason": "email is not configured for your account",
		})
		return
	}
	d, err := h.build(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if err := notifyMailer.Notify(user.Email, "Your Revah digest",
		digestEmailBody(user.FullName, d)); err != nil {
		writeError(w, http.StatusBadGateway, errors.New("could not send email"))
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"sent": true})
}
