package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// CalendarHandler serves /api/v1/calendar — per-user calendar feed tokens —
// and the public iCalendar (.ics) feed mounted separately on /api/v1/ics.
type CalendarHandler struct {
	q *db.Queries
}

// NewCalendarHandler wires the handler to the query layer.
func NewCalendarHandler(q *db.Queries) *CalendarHandler {
	return &CalendarHandler{q: q}
}

// Routes builds the authed sub-router mounted at /api/v1/calendar.
func (h *CalendarHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.get)
	r.Post("/", h.rotate)
	r.Delete("/", h.revoke)
	return r
}

func (h *CalendarHandler) get(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	token, err := h.q.GetUserCalendarToken(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"token": token})
}

func (h *CalendarHandler) rotate(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	token := shareToken()
	if err := h.q.SetUserCalendarToken(r.Context(), db.SetUserCalendarTokenParams{
		ID: *actor, Token: &token,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"token": token})
}

func (h *CalendarHandler) revoke(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	if err := h.q.ClearUserCalendarToken(r.Context(), *actor); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// icsEscape escapes text for an iCalendar property value (RFC 5545).
func icsEscape(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, ";", "\\;")
	s = strings.ReplaceAll(s, ",", "\\,")
	s = strings.ReplaceAll(s, "\r\n", "\\n")
	s = strings.ReplaceAll(s, "\n", "\\n")
	return strings.ReplaceAll(s, "\r", "")
}

func icsTime(t time.Time) string {
	return t.UTC().Format("20060102T150405Z")
}

// Feed renders a read-only iCalendar of the token owner's due tasks. It is
// mounted publicly (no auth) — the unguessable token is the credential, so
// calendar apps can subscribe to it directly.
func (h *CalendarHandler) Feed(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	token = strings.TrimSuffix(token, ".ics")
	if token == "" {
		writeError(w, http.StatusNotFound, errors.New("not found"))
		return
	}
	u, err := h.q.GetUserByCalendarToken(r.Context(), &token)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("feed not found"))
		return
	}
	tasks, err := h.q.ListCalendarTasks(r.Context(), u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	now := time.Now()
	var b strings.Builder
	b.WriteString("BEGIN:VCALENDAR\r\n")
	b.WriteString("VERSION:2.0\r\n")
	b.WriteString("PRODID:-//Revah//Management System//EN\r\n")
	b.WriteString("CALSCALE:GREGORIAN\r\n")
	b.WriteString("METHOD:PUBLISH\r\n")
	b.WriteString("X-WR-CALNAME:" + icsEscape("Revah tasks") + "\r\n")
	for _, t := range tasks {
		if !t.DueDate.Valid {
			continue
		}
		start := t.DueDate.Time
		end := start.Add(30 * time.Minute)
		b.WriteString("BEGIN:VEVENT\r\n")
		b.WriteString("UID:task-" + strconv.FormatInt(t.ID, 10) + "@revah\r\n")
		b.WriteString("DTSTAMP:" + icsTime(now) + "\r\n")
		b.WriteString("DTSTART:" + icsTime(start) + "\r\n")
		b.WriteString("DTEND:" + icsTime(end) + "\r\n")
		b.WriteString("SUMMARY:" + icsEscape(t.Title) + "\r\n")
		if strings.TrimSpace(t.Description) != "" {
			b.WriteString("DESCRIPTION:" + icsEscape(t.Description) + "\r\n")
		}
		b.WriteString("END:VEVENT\r\n")
	}
	b.WriteString("END:VCALENDAR\r\n")

	w.Header().Set("Content-Type", "text/calendar; charset=utf-8")
	w.Header().Set("Content-Disposition", `inline; filename="revah-tasks.ics"`)
	_, _ = w.Write([]byte(b.String()))
}
