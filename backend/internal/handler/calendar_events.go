package handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
	"github.com/revah-tech/revahms/backend/internal/nepdate"
)

// CalendarEventHandler serves /api/v1/events — a user's own calendar entries:
// notes, birthdays, anniversaries, meetings.
//
// Everything here is private. Each query is scoped by the caller's id, in the
// WHERE clause rather than only in this file, so a guessed id cannot reach
// somebody else's birthday.
type CalendarEventHandler struct {
	q *db.Queries
}

// NewCalendarEventHandler wires the handler to the query layer.
func NewCalendarEventHandler(q *db.Queries) *CalendarEventHandler {
	return &CalendarEventHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/events.
func (h *CalendarEventHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

var eventKinds = map[string]bool{
	"note":        true,
	"birthday":    true,
	"anniversary": true,
	"meeting":     true,
	"custom":      true,
}

// repeatModes: 'none', or the calendar the event repeats in. See
// NextOccurrence — the two calendars genuinely disagree about when "next year"
// is, and the event has to say which one it means.
var repeatModes = map[string]bool{
	"none": true,
	"ad":   true,
	"bs":   true,
}

type eventResponse struct {
	ID         int64  `json:"id"`
	Date       string `json:"date"`
	Kind       string `json:"kind"`
	Title      string `json:"title"`
	Note       string `json:"note"`
	StartTime  string `json:"start_time"`
	EndTime    string `json:"end_time"`
	RepeatIn   string `json:"repeat_in"`
	RemindDays *int32 `json:"remind_days"`
	NextOccurs string `json:"next_occurs"`
}

func eventFrom(e db.CalendarEvent) eventResponse {
	return eventResponse{
		ID:         e.ID,
		Date:       fmtDate(e.EventDate),
		Kind:       e.Kind,
		Title:      e.Title,
		Note:       e.Note,
		StartTime:  fmtTime(e.StartTime),
		EndTime:    fmtTime(e.EndTime),
		RepeatIn:   e.RepeatIn,
		RemindDays: e.RemindDays,
		NextOccurs: fmtDate(e.NextOccurs),
	}
}

// list returns the caller's events in the window, and every repeating event
// they own — a birthday recorded in 1994 still belongs on this year's grid, and
// its stored date is nowhere near the window asked for.
func (h *CalendarEventHandler) list(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("sign in"))
		return
	}
	now := time.Now()
	from, err := datePtr(r.URL.Query().Get("from"))
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid from date"))
		return
	}
	if !from.Valid {
		from, _ = datePtr(now.AddDate(-1, 0, 0).Format(dateLayout))
	}
	to, err := datePtr(r.URL.Query().Get("to"))
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid to date"))
		return
	}
	if !to.Valid {
		to, _ = datePtr(now.AddDate(2, 0, 0).Format(dateLayout))
	}

	rows, err := h.q.ListCalendarEvents(r.Context(), db.ListCalendarEventsParams{
		UserID:   *actor,
		FromDate: from,
		ToDate:   to,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]eventResponse, 0, len(rows))
	seen := make(map[int64]bool, len(rows))
	for _, e := range rows {
		out = append(out, eventFrom(e))
		seen[e.ID] = true
	}

	repeating, err := h.q.ListRepeatingCalendarEvents(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	for _, e := range repeating {
		if !seen[e.ID] {
			out = append(out, eventFrom(e))
		}
	}
	writeJSON(w, http.StatusOK, out)
}

type eventBody struct {
	Date       string `json:"date"`
	Kind       string `json:"kind"`
	Title      string `json:"title"`
	Note       string `json:"note"`
	StartTime  string `json:"start_time"`
	EndTime    string `json:"end_time"`
	RepeatIn   string `json:"repeat_in"`
	RemindDays *int32 `json:"remind_days"`
}

// parsed holds a validated body, ready for the query layer.
type parsedEvent struct {
	date       pgtype.Date
	kind       string
	title      string
	note       string
	start      pgtype.Time
	end        pgtype.Time
	repeatIn   string
	remindDays *int32
	nextOccurs pgtype.Date
}

func decodeEvent(r *http.Request) (parsedEvent, error) {
	var b eventBody
	var p parsedEvent
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		return p, err
	}

	p.title = strings.TrimSpace(b.Title)
	if p.title == "" {
		return p, errors.New("a title is required")
	}
	p.note = strings.TrimSpace(b.Note)

	date, err := datePtr(b.Date)
	if err != nil || !date.Valid {
		return p, errors.New("a date (YYYY-MM-DD) is required")
	}
	p.date = date

	p.kind = strings.TrimSpace(strings.ToLower(b.Kind))
	if p.kind == "" {
		p.kind = "note"
	}
	if !eventKinds[p.kind] {
		return p, fmt.Errorf("unknown kind %q", b.Kind)
	}

	p.repeatIn = strings.TrimSpace(strings.ToLower(b.RepeatIn))
	if p.repeatIn == "" {
		p.repeatIn = "none"
	}
	if !repeatModes[p.repeatIn] {
		return p, fmt.Errorf("unknown repeat_in %q", b.RepeatIn)
	}

	if p.start, err = timePtr(b.StartTime); err != nil {
		return p, errors.New("start_time must be HH:MM")
	}
	if p.end, err = timePtr(b.EndTime); err != nil {
		return p, errors.New("end_time must be HH:MM")
	}
	if p.end.Valid && !p.start.Valid {
		return p, errors.New("an end time needs a start time")
	}
	if p.start.Valid && p.end.Valid &&
		p.end.Microseconds < p.start.Microseconds {
		return p, errors.New("the event must end after it starts")
	}

	if b.RemindDays != nil {
		if *b.RemindDays < 0 || *b.RemindDays > 365 {
			return p, errors.New("remind_days must be between 0 and 365")
		}
		p.remindDays = b.RemindDays
	}

	// Resolve the recurrence now, so the reminder sweep is a plain date
	// comparison rather than a calendar conversion per row.
	when, err := nepdate.NextOccurrence(
		p.repeatIn, date.Time, time.Now())
	if err != nil {
		return p, err
	}
	p.nextOccurs = pgtype.Date{Time: when, Valid: true}
	return p, nil
}

func (h *CalendarEventHandler) create(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("sign in"))
		return
	}
	p, err := decodeEvent(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	e, err := h.q.CreateCalendarEvent(r.Context(), db.CreateCalendarEventParams{
		UserID:     *actor,
		EventDate:  p.date,
		Kind:       p.kind,
		Title:      p.title,
		Note:       p.note,
		StartTime:  p.start,
		EndTime:    p.end,
		RepeatIn:   p.repeatIn,
		RemindDays: p.remindDays,
		NextOccurs: p.nextOccurs,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, eventFrom(e))
}

func (h *CalendarEventHandler) update(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("sign in"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	p, err := decodeEvent(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	e, err := h.q.UpdateCalendarEvent(r.Context(), db.UpdateCalendarEventParams{
		ID:         id,
		UserID:     *actor,
		EventDate:  p.date,
		Kind:       p.kind,
		Title:      p.title,
		Note:       p.note,
		StartTime:  p.start,
		EndTime:    p.end,
		RepeatIn:   p.repeatIn,
		RemindDays: p.remindDays,
		NextOccurs: p.nextOccurs,
	})
	if err != nil {
		// The query is scoped by user_id, so no rows means either it does not
		// exist or it is not the caller's. Both answer the same, on purpose:
		// telling them apart would leak that somebody else's event exists.
		writeError(w, http.StatusNotFound, errors.New("event not found"))
		return
	}
	writeJSON(w, http.StatusOK, eventFrom(e))
}

func (h *CalendarEventHandler) delete(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("sign in"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	n, err := h.q.DeleteCalendarEvent(r.Context(), db.DeleteCalendarEventParams{
		ID:     id,
		UserID: *actor,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if n == 0 {
		writeError(w, http.StatusNotFound, errors.New("event not found"))
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
