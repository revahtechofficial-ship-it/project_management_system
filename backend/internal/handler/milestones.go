package handler

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// MilestoneHandler serves the /api/v1/milestones resource.
type MilestoneHandler struct {
	q *db.Queries
}

// NewMilestoneHandler wires the handler to the generated query layer.
func NewMilestoneHandler(q *db.Queries) *MilestoneHandler {
	return &MilestoneHandler{q: q}
}

// Routes builds a sub-router intended to be mounted under /api/v1/milestones.
func (h *MilestoneHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

func (h *MilestoneHandler) list(w http.ResponseWriter, r *http.Request) {
	ms, err := h.q.ListMilestones(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, ms)
}

type milestoneBody struct {
	Name      string `json:"name"`
	DueDate   string `json:"due_date"`
	ProjectID *int64 `json:"project_id"`
	Done      bool   `json:"done"`
}

func (h *MilestoneHandler) create(w http.ResponseWriter, r *http.Request) {
	var b milestoneBody
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	due, err := time.Parse("2006-01-02", b.DueDate)
	if err != nil {
		writeError(w, http.StatusBadRequest,
			errors.New("due_date is required (YYYY-MM-DD)"))
		return
	}
	m, err := h.q.CreateMilestone(r.Context(), db.CreateMilestoneParams{
		ProjectID: b.ProjectID,
		Name:      name,
		DueDate:   due,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	notify(r.Context(), h.q, "milestone", "Milestone created", name)
	writeJSON(w, http.StatusCreated, m)
}

func (h *MilestoneHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b milestoneBody
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	due, err := time.Parse("2006-01-02", b.DueDate)
	if err != nil {
		writeError(w, http.StatusBadRequest,
			errors.New("due_date is required (YYYY-MM-DD)"))
		return
	}
	m, err := h.q.UpdateMilestone(r.Context(), db.UpdateMilestoneParams{
		ID:      id,
		Name:    name,
		DueDate: due,
		Done:    b.Done,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("milestone not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, m)
}

func (h *MilestoneHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteMilestone(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
