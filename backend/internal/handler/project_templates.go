package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// ProjectTemplateHandler serves /api/v1/project-templates — reusable project
// blueprints the New-project form is pre-filled from.
type ProjectTemplateHandler struct {
	q *db.Queries
}

// NewProjectTemplateHandler wires the handler to the query layer.
func NewProjectTemplateHandler(q *db.Queries) *ProjectTemplateHandler {
	return &ProjectTemplateHandler{q: q}
}

// Routes builds a sub-router for /api/v1/project-templates.
func (h *ProjectTemplateHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Delete("/{id}", h.delete)
	return r
}

type projectTemplateResponse struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	ProjectName string `json:"project_name"`
	Description string `json:"description"`
	Status      string `json:"status"`
}

func projectTemplateFromModel(t db.ProjectTemplate) projectTemplateResponse {
	return projectTemplateResponse{
		ID: t.ID, Name: t.Name, ProjectName: t.ProjectName,
		Description: t.Description, Status: t.Status,
	}
}

func validProjectStatus(s string) bool {
	switch s {
	case "planning", "active", "on_hold", "completed":
		return true
	default:
		return false
	}
}

func (h *ProjectTemplateHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListProjectTemplates(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]projectTemplateResponse, 0, len(rows))
	for _, t := range rows {
		out = append(out, projectTemplateFromModel(t))
	}
	writeJSON(w, http.StatusOK, out)
}

type projectTemplateBody struct {
	Name        string `json:"name"`
	ProjectName string `json:"project_name"`
	Description string `json:"description"`
	Status      string `json:"status"`
}

func (h *ProjectTemplateHandler) create(w http.ResponseWriter, r *http.Request) {
	var b projectTemplateBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a template name is required"))
		return
	}
	status := b.Status
	if !validProjectStatus(status) {
		status = "active"
	}
	t, err := h.q.CreateProjectTemplate(r.Context(), db.CreateProjectTemplateParams{
		Name:        name,
		ProjectName: strings.TrimSpace(b.ProjectName),
		Description: strings.TrimSpace(b.Description),
		Status:      status,
		CreatedBy:   actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, projectTemplateFromModel(t))
}

func (h *ProjectTemplateHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteProjectTemplate(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
