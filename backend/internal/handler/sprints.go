package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// SprintHandler serves /api/v1/sprints — time-boxed iterations of tasks.
type SprintHandler struct {
	q *db.Queries
}

// NewSprintHandler wires the handler to the query layer.
func NewSprintHandler(q *db.Queries) *SprintHandler {
	return &SprintHandler{q: q}
}

// Routes builds a sub-router for /api/v1/sprints.
func (h *SprintHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Post("/{id}/start", h.start)
	r.Post("/{id}/complete", h.complete)
	r.Delete("/{id}", h.delete)
	return r
}

type sprintResponse struct {
	ID          int64      `json:"id"`
	Name        string     `json:"name"`
	Goal        string     `json:"goal"`
	Status      string     `json:"status"`
	StartDate   *time.Time `json:"start_date"`
	EndDate     *time.Time `json:"end_date"`
	TaskCount   int32      `json:"task_count"`
	DoneCount   int32      `json:"done_count"`
	TotalPoints int32      `json:"total_points"`
	DonePoints  int32      `json:"done_points"`
}

func sprintFromRow(r db.ListSprintsRow) sprintResponse {
	return sprintResponse{
		ID: r.ID, Name: r.Name, Goal: r.Goal, Status: r.Status,
		StartDate: tsPtr(r.StartDate), EndDate: tsPtr(r.EndDate),
		TaskCount: r.TaskCount, DoneCount: r.DoneCount,
		TotalPoints: r.TotalPoints, DonePoints: r.DonePoints,
	}
}

func sprintFromModel(s db.Sprint) sprintResponse {
	return sprintResponse{
		ID: s.ID, Name: s.Name, Goal: s.Goal, Status: s.Status,
		StartDate: tsPtr(s.StartDate), EndDate: tsPtr(s.EndDate),
	}
}

func validSprintStatus(s string) bool {
	switch s {
	case "planned", "active", "completed":
		return true
	default:
		return false
	}
}

func (h *SprintHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListSprints(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]sprintResponse, 0, len(rows))
	for _, s := range rows {
		out = append(out, sprintFromRow(s))
	}
	writeJSON(w, http.StatusOK, out)
}

type sprintBody struct {
	Name      string  `json:"name"`
	Goal      string  `json:"goal"`
	Status    string  `json:"status"`
	StartDate *string `json:"start_date"`
	EndDate   *string `json:"end_date"`
}

func (h *SprintHandler) create(w http.ResponseWriter, r *http.Request) {
	var b sprintBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a sprint name is required"))
		return
	}
	start, due, err := sprintDates(b)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	status := b.Status
	if !validSprintStatus(status) {
		status = "planned"
	}
	s, err := h.q.CreateSprint(r.Context(), db.CreateSprintParams{
		Name:      name,
		Goal:      strings.TrimSpace(b.Goal),
		Status:    status,
		StartDate: start,
		EndDate:   due,
		CreatedBy: actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, sprintFromModel(s))
}

func (h *SprintHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b sprintBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a sprint name is required"))
		return
	}
	start, due, err := sprintDates(b)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	s, err := h.q.UpdateSprint(r.Context(), db.UpdateSprintParams{
		ID: id, Name: name, Goal: strings.TrimSpace(b.Goal),
		StartDate: start, EndDate: due,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("sprint not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, sprintFromModel(s))
}

func (h *SprintHandler) start(w http.ResponseWriter, r *http.Request) {
	h.setStatus(w, r, "active")
}

// complete marks the sprint done and runs the automation: unfinished tasks are
// returned to the backlog so the next sprint can pick them up.
func (h *SprintHandler) complete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	_ = h.q.MoveSprintTasksToBacklog(r.Context(), &id)
	s, err := h.q.SetSprintStatus(r.Context(), db.SetSprintStatusParams{
		ID: id, Status: "completed",
	})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("sprint not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, sprintFromModel(s))
}

func (h *SprintHandler) setStatus(w http.ResponseWriter, r *http.Request, status string) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	s, err := h.q.SetSprintStatus(r.Context(), db.SetSprintStatusParams{
		ID: id, Status: status,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("sprint not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, sprintFromModel(s))
}

func (h *SprintHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteSprint(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// sprintDates parses the optional start/end "YYYY-MM-DD" fields.
func sprintDates(b sprintBody) (start, end pgtype.Timestamptz, err error) {
	start, err = parseDue(b.StartDate)
	if err != nil {
		return start, end, errors.New("invalid start_date, expected YYYY-MM-DD")
	}
	end, err = parseDue(b.EndDate)
	if err != nil {
		return start, end, errors.New("invalid end_date, expected YYYY-MM-DD")
	}
	return start, end, nil
}
