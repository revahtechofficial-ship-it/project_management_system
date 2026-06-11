package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
	"github.com/revah-tech/revahms/backend/internal/schedule"
)

// DependencyHandler serves the /api/v1/dependencies resource and owns the
// auto-rescheduling that keeps the schedule consistent.
type DependencyHandler struct {
	q *db.Queries
}

// NewDependencyHandler wires the handler to the generated query layer.
func NewDependencyHandler(q *db.Queries) *DependencyHandler {
	return &DependencyHandler{q: q}
}

// Routes builds a sub-router intended to be mounted under
// /api/v1/dependencies.
func (h *DependencyHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Delete("/{id}", h.delete)
	return r
}

func (h *DependencyHandler) list(w http.ResponseWriter, r *http.Request) {
	deps, err := h.q.ListDependencies(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, deps)
}

type dependencyBody struct {
	PredecessorID int64  `json:"predecessor_id"`
	SuccessorID   int64  `json:"successor_id"`
	Type          string `json:"type"`
}

func (h *DependencyHandler) create(w http.ResponseWriter, r *http.Request) {
	var b dependencyBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.PredecessorID == 0 || b.SuccessorID == 0 {
		writeError(w, http.StatusBadRequest,
			errors.New("predecessor_id and successor_id are required"))
		return
	}
	if b.PredecessorID == b.SuccessorID {
		writeError(w, http.StatusBadRequest,
			errors.New("a task cannot depend on itself"))
		return
	}
	depType := b.Type
	if depType == "" {
		depType = "finish_to_start"
	}
	if !validDepType(depType) {
		writeError(w, http.StatusBadRequest,
			errors.New("invalid dependency type"))
		return
	}

	existing, err := h.q.ListDependencies(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	for _, d := range existing {
		if d.PredecessorID == b.PredecessorID &&
			d.SuccessorID == b.SuccessorID {
			writeError(w, http.StatusConflict,
				errors.New("this dependency already exists"))
			return
		}
	}
	// Adding pred -> succ forms a cycle iff succ already reaches pred.
	if schedule.Reaches(toScheduleDeps(existing), b.SuccessorID, b.PredecessorID) {
		writeError(w, http.StatusBadRequest,
			errors.New("this would create a circular dependency"))
		return
	}

	dep, err := h.q.CreateDependency(r.Context(), db.CreateDependencyParams{
		PredecessorID: b.PredecessorID,
		SuccessorID:   b.SuccessorID,
		Type:          depType,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if err := rescheduleAll(r.Context(), h.q); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, dep)
}

func (h *DependencyHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteDependency(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func validDepType(t string) bool {
	switch t {
	case "finish_to_start", "start_to_start",
		"finish_to_finish", "start_to_finish":
		return true
	default:
		return false
	}
}

// rescheduleAll loads the whole task/dependency graph, pushes successors
// forward to satisfy every constraint, and persists the tasks that moved.
func rescheduleAll(ctx context.Context, q *db.Queries) error {
	tasks, err := q.ListTasksRaw(ctx)
	if err != nil {
		return err
	}
	deps, err := q.ListDependencies(ctx)
	if err != nil {
		return err
	}
	changes := schedule.Normalize(toScheduleTasks(tasks), toScheduleDeps(deps))
	for id, ch := range changes {
		if err := q.SetTaskDates(ctx, db.SetTaskDatesParams{
			ID:        id,
			StartDate: pgtype.Timestamptz{Time: ch.Start, Valid: true},
			DueDate:   pgtype.Timestamptz{Time: ch.Due, Valid: true},
		}); err != nil {
			return err
		}
	}
	return nil
}

func toScheduleTasks(rows []db.Task) []schedule.Task {
	out := make([]schedule.Task, 0, len(rows))
	for _, r := range rows {
		st := schedule.Task{ID: r.ID}
		if r.StartDate.Valid && r.DueDate.Valid {
			st.Start = r.StartDate.Time
			st.Due = r.DueDate.Time
			st.HasDates = true
		}
		out = append(out, st)
	}
	return out
}

func toScheduleDeps(rows []db.TaskDependency) []schedule.Dep {
	out := make([]schedule.Dep, 0, len(rows))
	for _, d := range rows {
		out = append(out, schedule.Dep{
			Pred: d.PredecessorID,
			Succ: d.SuccessorID,
			Type: d.Type,
		})
	}
	return out
}
