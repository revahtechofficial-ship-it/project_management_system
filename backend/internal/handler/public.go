package handler

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// PublicHandler serves unauthenticated, read-only views reached via a share
// token (mounted outside the app JWT).
type PublicHandler struct {
	q *db.Queries
}

// NewPublicHandler wires the handler to the query layer.
func NewPublicHandler(q *db.Queries) *PublicHandler {
	return &PublicHandler{q: q}
}

// SharedProject returns a read-only project and its tasks for a valid token.
func (h *PublicHandler) SharedProject(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	if token == "" {
		writeError(w, http.StatusBadRequest, errors.New("missing token"))
		return
	}
	p, err := h.q.GetSharedProject(r.Context(), token)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("not found"))
		return
	}
	tasks, err := h.q.ListSharedProjectTasks(r.Context(), token)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	list := make([]map[string]any, 0, len(tasks))
	for _, t := range tasks {
		list = append(list, map[string]any{
			"id":       t.ID,
			"title":    t.Title,
			"done":     t.Done,
			"status":   t.Status,
			"due_date": tsPtr(t.DueDate),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"project": map[string]any{
			"id":          p.ID,
			"name":        p.Name,
			"description": p.Description,
			"status":      p.Status,
			"due_date":    tsPtr(p.DueDate),
		},
		"tasks": list,
	})
}
