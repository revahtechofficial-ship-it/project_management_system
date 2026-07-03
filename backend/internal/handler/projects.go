package handler

import (
	"crypto/rand"
	"encoding/base64"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// ProjectHandler serves the /api/v1/projects resource.
type ProjectHandler struct {
	q *db.Queries
}

// NewProjectHandler wires the handler to the generated query layer.
func NewProjectHandler(q *db.Queries) *ProjectHandler {
	return &ProjectHandler{q: q}
}

// Routes builds a sub-router intended to be mounted under /api/v1/projects.
func (h *ProjectHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	r.Get("/{id}/share", h.getShare)
	r.Post("/{id}/share", h.createShare)
	r.Delete("/{id}/share", h.revokeShare)
	return r
}

// shareToken returns a URL-safe random token for a public share link.
func shareToken() string {
	b := make([]byte, 12)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

// getShare returns the project's current public share token, or null.
func (h *ProjectHandler) getShare(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	tok, err := h.q.GetProjectShareToken(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeJSON(w, http.StatusOK, map[string]any{"token": nil})
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"token": tok})
}

// createShare publishes a read-only public link (admin-only), returning the
// existing token if one is already set.
func (h *ProjectHandler) createShare(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if tok, gerr := h.q.GetProjectShareToken(r.Context(), id); gerr == nil {
		writeJSON(w, http.StatusOK, map[string]any{"token": tok})
		return
	}
	tok, err := h.q.CreateProjectShare(r.Context(), db.CreateProjectShareParams{
		Token:     shareToken(),
		ProjectID: id,
		CreatedBy: actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"token": tok})
}

// revokeShare disables the project's public link (admin-only).
func (h *ProjectHandler) revokeShare(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.RevokeProjectShare(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// projectResponse is the clean JSON shape the frontend consumes. It replaces
// pgtype.Timestamptz (which marshals poorly) with a nullable RFC3339 time.
type projectResponse struct {
	ID          int64      `json:"id"`
	Name        string     `json:"name"`
	Description string     `json:"description"`
	Status      string     `json:"status"`
	DueDate     *time.Time `json:"due_date"`
	TotalTasks  int32      `json:"total_tasks"`
	DoneTasks   int32      `json:"done_tasks"`
	MemberNames []string   `json:"member_names"`
	SpaceID     *int64     `json:"space_id"`
	FolderID    *int64     `json:"folder_id"`
	CreatedAt   time.Time  `json:"created_at"`
}

func projectFromRow(r db.ListProjectsRow) projectResponse {
	return projectResponse{
		ID:          r.ID,
		Name:        r.Name,
		Description: r.Description,
		Status:      r.Status,
		DueDate:     tsPtr(r.DueDate),
		TotalTasks:  r.TotalTasks,
		DoneTasks:   r.DoneTasks,
		MemberNames: r.MemberNames,
		SpaceID:     r.SpaceID,
		FolderID:    r.FolderID,
		CreatedAt:   r.CreatedAt,
	}
}

func projectFromModel(p db.Project) projectResponse {
	return projectResponse{
		ID:          p.ID,
		Name:        p.Name,
		Description: p.Description,
		Status:      p.Status,
		DueDate:     tsPtr(p.DueDate),
		TotalTasks:  0,
		DoneTasks:   0,
		MemberNames: []string{},
		SpaceID:     p.SpaceID,
		FolderID:    p.FolderID,
		CreatedAt:   p.CreatedAt,
	}
}

func (h *ProjectHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListProjects(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]projectResponse, 0, len(rows))
	for _, row := range rows {
		out = append(out, projectFromRow(row))
	}
	writeJSON(w, http.StatusOK, out)
}

type projectBody struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Status      string  `json:"status"`
	DueDate     *string `json:"due_date"`
	SpaceID     *int64  `json:"space_id"`
	FolderID    *int64  `json:"folder_id"`
}

func (h *ProjectHandler) create(w http.ResponseWriter, r *http.Request) {
	var b projectBody
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Name == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	due, err := parseDue(b.DueDate)
	if err != nil {
		writeError(w, http.StatusBadRequest,
			errors.New("invalid due_date, expected YYYY-MM-DD"))
		return
	}
	var createdBy *int64
	if c, ok := account.FromContext(r.Context()); ok {
		uid := c.UserID
		createdBy = &uid
	}
	p, err := h.q.CreateProject(r.Context(), db.CreateProjectParams{
		Name:        b.Name,
		Description: b.Description,
		Status:      statusOrDefault(b.Status),
		DueDate:     due,
		CreatedBy:   createdBy,
		SpaceID:     b.SpaceID,
		FolderID:    b.FolderID,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, projectFromModel(p))
}

func (h *ProjectHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b projectBody
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Name == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	due, err := parseDue(b.DueDate)
	if err != nil {
		writeError(w, http.StatusBadRequest,
			errors.New("invalid due_date, expected YYYY-MM-DD"))
		return
	}
	p, err := h.q.UpdateProject(r.Context(), db.UpdateProjectParams{
		ID:          id,
		Name:        b.Name,
		Description: b.Description,
		Status:      statusOrDefault(b.Status),
		DueDate:     due,
		SpaceID:     b.SpaceID,
		FolderID:    b.FolderID,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("project not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, projectFromModel(p))
}

func (h *ProjectHandler) delete(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteProject(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func statusOrDefault(s string) string {
	if s == "" {
		return "active"
	}
	return s
}

// parseDue turns an optional "YYYY-MM-DD" string into a nullable timestamptz.
func parseDue(s *string) (pgtype.Timestamptz, error) {
	if s == nil || *s == "" {
		return pgtype.Timestamptz{Valid: false}, nil
	}
	t, err := time.Parse("2006-01-02", *s)
	if err != nil {
		return pgtype.Timestamptz{}, err
	}
	return pgtype.Timestamptz{Time: t, Valid: true}, nil
}

func tsPtr(t pgtype.Timestamptz) *time.Time {
	if !t.Valid {
		return nil
	}
	v := t.Time
	return &v
}
