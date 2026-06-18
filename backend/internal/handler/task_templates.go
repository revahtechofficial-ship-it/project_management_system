package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// TaskTemplateHandler serves /api/v1/task-templates — reusable task blueprints
// the client pre-fills the New-task form from.
type TaskTemplateHandler struct {
	q *db.Queries
}

// NewTaskTemplateHandler wires the handler to the query layer.
func NewTaskTemplateHandler(q *db.Queries) *TaskTemplateHandler {
	return &TaskTemplateHandler{q: q}
}

// Routes builds a sub-router intended to be mounted under /api/v1/task-templates.
func (h *TaskTemplateHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Delete("/{id}", h.delete)
	return r
}

type taskTemplateResponse struct {
	ID              int64    `json:"id"`
	Name            string   `json:"name"`
	Title           string   `json:"title"`
	Description     string   `json:"description"`
	Status          string   `json:"status"`
	Priority        string   `json:"priority"`
	Recurrence      string   `json:"recurrence"`
	EstimateMinutes int32    `json:"estimate_minutes"`
	Tags            []string `json:"tags"`
	ProjectID       *int64   `json:"project_id"`
}

func taskTemplateFromModel(t db.TaskTemplate) taskTemplateResponse {
	return taskTemplateResponse{
		ID: t.ID, Name: t.Name, Title: t.Title, Description: t.Description,
		Status: t.Status, Priority: t.Priority, Recurrence: t.Recurrence,
		EstimateMinutes: t.EstimateMinutes, Tags: t.Tags, ProjectID: t.ProjectID,
	}
}

func (h *TaskTemplateHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListTaskTemplates(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]taskTemplateResponse, 0, len(rows))
	for _, t := range rows {
		out = append(out, taskTemplateFromModel(t))
	}
	writeJSON(w, http.StatusOK, out)
}

type taskTemplateBody struct {
	Name            string   `json:"name"`
	Title           string   `json:"title"`
	Description     string   `json:"description"`
	Status          string   `json:"status"`
	Priority        string   `json:"priority"`
	Recurrence      string   `json:"recurrence"`
	EstimateMinutes int32    `json:"estimate_minutes"`
	Tags            []string `json:"tags"`
	ProjectID       *int64   `json:"project_id"`
}

func (h *TaskTemplateHandler) create(w http.ResponseWriter, r *http.Request) {
	var b taskTemplateBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a template name is required"))
		return
	}
	// Normalize the saved defaults so an instantiated task is always valid.
	status := statusOrTodo(b.Status)
	if ok, _ := h.q.StatusKeyExists(r.Context(), status); !ok {
		status = "todo"
	}
	priority := priorityOrNone(b.Priority)
	if !validPriority(priority) {
		priority = "none"
	}
	recurrence := recurrenceOrNone(b.Recurrence)
	if !validRecurrence(recurrence) {
		recurrence = "none"
	}
	t, err := h.q.CreateTaskTemplate(r.Context(), db.CreateTaskTemplateParams{
		Name:            name,
		Title:           strings.TrimSpace(b.Title),
		Description:     strings.TrimSpace(b.Description),
		Status:          status,
		Priority:        priority,
		Recurrence:      recurrence,
		EstimateMinutes: clampEstimate(b.EstimateMinutes),
		Tags:            sanitizeTags(b.Tags),
		ProjectID:       b.ProjectID,
		CreatedBy:       actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, taskTemplateFromModel(t))
}

func (h *TaskTemplateHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteTaskTemplate(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
