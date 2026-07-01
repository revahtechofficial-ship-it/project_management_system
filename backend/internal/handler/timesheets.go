package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// TimesheetHandler serves /api/v1/timesheets — weekly timesheet submission and
// manager approval, built on top of the time entries.
type TimesheetHandler struct {
	q *db.Queries
}

// NewTimesheetHandler wires the handler to the query layer.
func NewTimesheetHandler(q *db.Queries) *TimesheetHandler {
	return &TimesheetHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/timesheets.
func (h *TimesheetHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.listMine)
	r.Post("/", h.submit)
	r.Get("/pending", h.pending)
	r.Post("/{id}/decide", h.decide)
	return r
}

type timesheetResponse struct {
	ID           int64      `json:"id"`
	UserID       int64      `json:"user_id"`
	UserName     string     `json:"user_name"`
	WeekStart    time.Time  `json:"week_start"`
	Status       string     `json:"status"`
	Minutes      int32      `json:"minutes"`
	Note         string     `json:"note"`
	ApproverName string     `json:"approver_name"`
	DecidedAt    *time.Time `json:"decided_at"`
	SubmittedAt  time.Time  `json:"submitted_at"`
}

func (h *TimesheetHandler) actor(r *http.Request) (int64, bool) {
	if c, ok := account.FromContext(r.Context()); ok {
		return c.UserID, true
	}
	return 0, false
}

// mondayOf snaps any day to 00:00 UTC on that week's Monday.
func mondayOf(t time.Time) time.Time {
	t = t.UTC()
	d := time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	offset := (int(d.Weekday()) + 6) % 7
	return d.AddDate(0, 0, -offset)
}

type submitBody struct {
	WeekStart string `json:"week_start"`
	Note      string `json:"note"`
}

func parseDay(s string) (time.Time, bool) {
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t, true
	}
	if t, err := time.Parse("2006-01-02", s); err == nil {
		return t, true
	}
	return time.Time{}, false
}

func (h *TimesheetHandler) submit(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b submitBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	day, ok := parseDay(b.WeekStart)
	if !ok {
		writeError(w, http.StatusBadRequest, errors.New("invalid week_start"))
		return
	}
	week := mondayOf(day)
	minutes, err := h.q.WeekMinutes(r.Context(), db.WeekMinutesParams{
		UserID:    uid,
		WeekStart: week,
		WeekEnd:   week.AddDate(0, 0, 7),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	row, err := h.q.SubmitTimesheet(r.Context(), db.SubmitTimesheetParams{
		UserID:    uid,
		WeekStart: week,
		Minutes:   minutes,
		Note:      strings.TrimSpace(b.Note),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, timesheetResponse{
		ID:          row.ID,
		UserID:      row.UserID,
		WeekStart:   row.WeekStart,
		Status:      row.Status,
		Minutes:     row.Minutes,
		Note:        row.Note,
		SubmittedAt: row.SubmittedAt,
	})
}

func (h *TimesheetHandler) listMine(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	rows, err := h.q.ListMyTimesheets(r.Context(), uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]timesheetResponse, 0, len(rows))
	for _, t := range rows {
		out = append(out, timesheetResponse{
			ID:           t.ID,
			UserID:       t.UserID,
			WeekStart:    t.WeekStart,
			Status:       t.Status,
			Minutes:      t.Minutes,
			Note:         t.Note,
			ApproverName: t.ApproverName,
			DecidedAt:    tsPtr(t.DecidedAt),
			SubmittedAt:  t.SubmittedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *TimesheetHandler) pending(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	rows, err := h.q.ListPendingTimesheets(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]timesheetResponse, 0, len(rows))
	for _, t := range rows {
		out = append(out, timesheetResponse{
			ID:          t.ID,
			UserID:      t.UserID,
			UserName:    t.UserName,
			WeekStart:   t.WeekStart,
			Status:      t.Status,
			Minutes:     t.Minutes,
			Note:        t.Note,
			SubmittedAt: t.SubmittedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type decideBody struct {
	Status string `json:"status"`
}

func (h *TimesheetHandler) decide(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b decideBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Status != "approved" && b.Status != "rejected" {
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
		return
	}
	approver := actorOf(r.Context())
	row, err := h.q.DecideTimesheet(r.Context(), db.DecideTimesheetParams{
		ID:         id,
		Status:     b.Status,
		ApproverID: approver,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	verb := "approved"
	if b.Status == "rejected" {
		verb = "rejected"
	}
	notifyUser(r.Context(), h.q, row.UserID, "timesheet",
		"Timesheet "+verb,
		"Your timesheet for the week of "+row.WeekStart.Format("Jan 2")+
			" was "+verb+".", "/time")
	writeJSON(w, http.StatusOK, timesheetResponse{
		ID:          row.ID,
		UserID:      row.UserID,
		WeekStart:   row.WeekStart,
		Status:      row.Status,
		Minutes:     row.Minutes,
		Note:        row.Note,
		DecidedAt:   tsPtr(row.DecidedAt),
		SubmittedAt: row.SubmittedAt,
	})
}
