package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// TimeHandler serves /api/v1/time-entries — the timer and time log. Every
// endpoint is scoped to the authenticated user.
type TimeHandler struct {
	q *db.Queries
}

// NewTimeHandler wires the handler to the query layer.
func NewTimeHandler(q *db.Queries) *TimeHandler {
	return &TimeHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/time-entries.
func (h *TimeHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Get("/active", h.active)
	r.Post("/start", h.start)
	r.Post("/{id}/stop", h.stop)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

type timeEntryResponse struct {
	ID          int64      `json:"id"`
	UserID      int64      `json:"user_id"`
	UserName    string     `json:"user_name"`
	TaskID      *int64     `json:"task_id"`
	TaskTitle   string     `json:"task_title"`
	Minutes     int32      `json:"minutes"`
	StartedAt   time.Time  `json:"started_at"`
	EndedAt     *time.Time `json:"ended_at"`
	Description string     `json:"description"`
	Billable    bool       `json:"billable"`
	Running     bool       `json:"running"`
}

func teFromGet(r db.GetTimeEntryRow) timeEntryResponse {
	return timeEntryResponse{
		ID:          r.ID,
		UserID:      r.UserID,
		UserName:    r.UserName,
		TaskID:      r.TaskID,
		TaskTitle:   r.TaskTitle,
		Minutes:     r.Minutes,
		StartedAt:   r.StartedAt,
		EndedAt:     tsPtr(r.EndedAt),
		Description: r.Description,
		Billable:    r.Billable,
		Running:     !r.EndedAt.Valid,
	}
}

func teFromList(r db.ListTimeEntriesRow) timeEntryResponse {
	return timeEntryResponse{
		ID:          r.ID,
		UserID:      r.UserID,
		UserName:    r.UserName,
		TaskID:      r.TaskID,
		TaskTitle:   r.TaskTitle,
		Minutes:     r.Minutes,
		StartedAt:   r.StartedAt,
		EndedAt:     tsPtr(r.EndedAt),
		Description: r.Description,
		Billable:    r.Billable,
		Running:     !r.EndedAt.Valid,
	}
}

func (h *TimeHandler) actor(r *http.Request) (int64, bool) {
	if c, ok := account.FromContext(r.Context()); ok {
		return c.UserID, true
	}
	return 0, false
}

// dayOr parses a YYYY-MM-DD query param, falling back to def.
func dayOr(s string, def time.Time) time.Time {
	if s == "" {
		return def
	}
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return def
	}
	return t
}

func (h *TimeHandler) list(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	now := time.Now()
	from := dayOr(r.URL.Query().Get("from"), now.AddDate(0, 0, -90))
	to := dayOr(r.URL.Query().Get("to"), now.AddDate(0, 0, 1))
	rows, err := h.q.ListTimeEntries(r.Context(), db.ListTimeEntriesParams{
		UserID: uid, FromTs: from, ToTs: to,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]timeEntryResponse, 0, len(rows))
	for _, e := range rows {
		out = append(out, teFromList(e))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *TimeHandler) active(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	row, err := h.q.GetActiveTimer(r.Context(), uid)
	if errors.Is(err, pgx.ErrNoRows) {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, teFromGet(toGetRow(row)))
}

type timeEntryBody struct {
	TaskID      *int64 `json:"task_id"`
	Minutes     int32  `json:"minutes"`
	Date        string `json:"date"`
	Description string `json:"description"`
	Billable    bool   `json:"billable"`
}

func (h *TimeHandler) start(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	// Stop any timer already running so there is only ever one.
	if cur, err := h.q.GetActiveTimer(r.Context(), uid); err == nil {
		_, _ = h.q.StopTimer(r.Context(), db.StopTimerParams{ID: cur.ID, UserID: uid})
	}
	var b timeEntryBody
	_ = json.NewDecoder(r.Body).Decode(&b)
	id, err := h.q.StartTimer(r.Context(), db.StartTimerParams{
		UserID:      uid,
		TaskID:      b.TaskID,
		Description: strings.TrimSpace(b.Description),
		Billable:    b.Billable,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.respond(w, r, id, http.StatusCreated)
}

func (h *TimeHandler) stop(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	stopped, err := h.q.StopTimer(r.Context(), db.StopTimerParams{ID: id, UserID: uid})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("no running timer"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.respond(w, r, stopped, http.StatusOK)
}

func (h *TimeHandler) create(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b timeEntryBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Minutes <= 0 {
		writeError(w, http.StatusBadRequest, errors.New("minutes must be positive"))
		return
	}
	id, err := h.q.CreateTimeEntry(r.Context(), db.CreateTimeEntryParams{
		UserID:      uid,
		TaskID:      b.TaskID,
		Minutes:     b.Minutes,
		StartedAt:   dayOr(b.Date, time.Now()),
		Description: strings.TrimSpace(b.Description),
		Billable:    b.Billable,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.respond(w, r, id, http.StatusCreated)
}

func (h *TimeHandler) update(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b timeEntryBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.q.UpdateTimeEntry(r.Context(), db.UpdateTimeEntryParams{
		ID:          id,
		UserID:      uid,
		TaskID:      b.TaskID,
		Minutes:     b.Minutes,
		StartedAt:   dayOr(b.Date, time.Now()),
		Description: strings.TrimSpace(b.Description),
		Billable:    b.Billable,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.respond(w, r, id, http.StatusOK)
}

func (h *TimeHandler) delete(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.actor(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteTimeEntry(r.Context(), db.DeleteTimeEntryParams{ID: id, UserID: uid}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// respond reloads a time entry (joined with its task/user) and writes it.
func (h *TimeHandler) respond(w http.ResponseWriter, r *http.Request, id int64, status int) {
	row, err := h.q.GetTimeEntry(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, status, teFromGet(row))
}

// toGetRow adapts an active-timer row to the shared GetTimeEntryRow shape.
func toGetRow(r db.GetActiveTimerRow) db.GetTimeEntryRow {
	return db.GetTimeEntryRow(r)
}
