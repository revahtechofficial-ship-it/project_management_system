package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// Default annual vacation allowance (days). A per-user allowance table could
// replace this later.
const leaveAllowance = 20

// LeaveHandler serves /api/v1/leave — time-off requests, approval and the
// team's "who's out" calendar.
type LeaveHandler struct {
	q *db.Queries
}

// NewLeaveHandler wires the handler to the query layer.
func NewLeaveHandler(q *db.Queries) *LeaveHandler {
	return &LeaveHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/leave.
func (h *LeaveHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.listMine)
	r.Get("/balance", h.balance)
	r.Get("/calendar", h.calendar)
	r.Get("/pending", h.pending)
	r.Post("/", h.create)
	r.Post("/{id}/decide", h.decide)
	r.Delete("/{id}", h.cancel)
	return r
}

type leaveResponse struct {
	ID           int64      `json:"id"`
	UserID       int64      `json:"user_id"`
	UserName     string     `json:"user_name"`
	Avatar       *string    `json:"avatar_url"`
	Type         string     `json:"type"`
	StartDate    time.Time  `json:"start_date"`
	EndDate      time.Time  `json:"end_date"`
	Status       string     `json:"status"`
	Note         string     `json:"note"`
	ApproverName string     `json:"approver_name"`
	DecidedAt    *time.Time `json:"decided_at"`
	CreatedAt    time.Time  `json:"created_at"`
}

func startOfDay(t time.Time) time.Time {
	t = t.UTC()
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func validLeaveType(s string) string {
	switch s {
	case "vacation", "sick", "personal", "other":
		return s
	default:
		return "vacation"
	}
}

func (h *LeaveHandler) listMine(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	rows, err := h.q.ListMyLeave(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]leaveResponse, 0, len(rows))
	for _, l := range rows {
		out = append(out, leaveResponse{
			ID:           l.ID,
			UserID:       l.UserID,
			Type:         l.Type,
			StartDate:    l.StartDate,
			EndDate:      l.EndDate,
			Status:       l.Status,
			Note:         l.Note,
			ApproverName: l.ApproverName,
			DecidedAt:    tsPtr(l.DecidedAt),
			CreatedAt:    l.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *LeaveHandler) balance(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	now := time.Now().UTC()
	yearStart := time.Date(now.Year(), 1, 1, 0, 0, 0, 0, time.UTC)
	used, err := h.q.UsedLeaveDays(r.Context(), db.UsedLeaveDaysParams{
		UserID:    *actor,
		YearStart: yearStart,
		YearEnd:   yearStart.AddDate(1, 0, 0),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{
		"used":      int(used),
		"allowance": leaveAllowance,
		"remaining": leaveAllowance - int(used),
	})
}

func (h *LeaveHandler) calendar(w http.ResponseWriter, r *http.Request) {
	start := startOfDay(time.Now())
	end := start.AddDate(0, 0, 45)
	if s := r.URL.Query().Get("start"); s != "" {
		if t, ok := parseDay(s); ok {
			start = startOfDay(t)
		}
	}
	if s := r.URL.Query().Get("end"); s != "" {
		if t, ok := parseDay(s); ok {
			end = startOfDay(t)
		}
	}
	rows, err := h.q.ListLeaveInRange(r.Context(), db.ListLeaveInRangeParams{
		RangeStart: start,
		RangeEnd:   end,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]leaveResponse, 0, len(rows))
	for _, l := range rows {
		out = append(out, leaveResponse{
			ID:        l.ID,
			UserID:    l.UserID,
			UserName:  l.UserName,
			Avatar:    avatarURLPtr(l.Avatar),
			Type:      l.Type,
			StartDate: l.StartDate,
			EndDate:   l.EndDate,
			Status:    l.Status,
			Note:      l.Note,
			CreatedAt: l.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *LeaveHandler) pending(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	rows, err := h.q.ListPendingLeave(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]leaveResponse, 0, len(rows))
	for _, l := range rows {
		out = append(out, leaveResponse{
			ID:        l.ID,
			UserID:    l.UserID,
			UserName:  l.UserName,
			Avatar:    avatarURLPtr(l.Avatar),
			Type:      l.Type,
			StartDate: l.StartDate,
			EndDate:   l.EndDate,
			Status:    l.Status,
			Note:      l.Note,
			CreatedAt: l.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type createLeaveBody struct {
	Type      string `json:"type"`
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
	Note      string `json:"note"`
}

func (h *LeaveHandler) create(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	var b createLeaveBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	start, ok1 := parseDay(b.StartDate)
	end, ok2 := parseDay(b.EndDate)
	if !ok1 || !ok2 {
		writeError(w, http.StatusBadRequest, errors.New("invalid dates"))
		return
	}
	start = startOfDay(start)
	end = startOfDay(end)
	if end.Before(start) {
		writeError(w, http.StatusBadRequest, errors.New("end before start"))
		return
	}
	row, err := h.q.CreateLeave(r.Context(), db.CreateLeaveParams{
		UserID:    *actor,
		Type:      validLeaveType(b.Type),
		StartDate: start,
		EndDate:   end,
		Note:      strings.TrimSpace(b.Note),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, leaveResponse{
		ID:        row.ID,
		UserID:    row.UserID,
		Type:      row.Type,
		StartDate: row.StartDate,
		EndDate:   row.EndDate,
		Status:    row.Status,
		Note:      row.Note,
		CreatedAt: row.CreatedAt,
	})
}

func (h *LeaveHandler) decide(w http.ResponseWriter, r *http.Request) {
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
	row, err := h.q.DecideLeave(r.Context(), db.DecideLeaveParams{
		ID:         id,
		Status:     b.Status,
		ApproverID: actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	notifyUser(r.Context(), h.q, row.UserID, "leave",
		"Leave "+b.Status,
		"Your time-off request from "+row.StartDate.Format("Jan 2")+
			" was "+b.Status+".", "/leave")
	writeJSON(w, http.StatusOK, leaveResponse{
		ID:        row.ID,
		UserID:    row.UserID,
		Type:      row.Type,
		StartDate: row.StartDate,
		EndDate:   row.EndDate,
		Status:    row.Status,
		Note:      row.Note,
		DecidedAt: tsPtr(row.DecidedAt),
		CreatedAt: row.CreatedAt,
	})
}

func (h *LeaveHandler) cancel(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.CancelLeave(r.Context(), db.CancelLeaveParams{
		ID: id, UserID: *actor,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
