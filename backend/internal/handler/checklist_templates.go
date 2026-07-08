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

// ChecklistTemplateHandler serves /api/v1/checklist-templates — reusable
// named checklists that can be applied to any task's checklist.
type ChecklistTemplateHandler struct {
	q *db.Queries
}

// NewChecklistTemplateHandler wires the handler to the query layer.
func NewChecklistTemplateHandler(q *db.Queries) *ChecklistTemplateHandler {
	return &ChecklistTemplateHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/checklist-templates.
func (h *ChecklistTemplateHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	r.Post("/{id}/apply", h.apply)
	return r
}

type checklistTemplateResponse struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	Category  string    `json:"category"`
	Items     []string  `json:"items"`
	CreatedAt time.Time `json:"created_at"`
}

func decodeItems(raw string) []string {
	items := []string{}
	_ = json.Unmarshal([]byte(raw), &items)
	return items
}

// cleanItems trims each entry and drops the blanks.
func cleanItems(items []string) []string {
	out := make([]string, 0, len(items))
	for _, it := range items {
		if s := strings.TrimSpace(it); s != "" {
			out = append(out, s)
		}
	}
	return out
}

func checklistTemplateFrom(t db.ChecklistTemplate) checklistTemplateResponse {
	return checklistTemplateResponse{
		ID:        t.ID,
		Name:      t.Name,
		Category:  t.Category,
		Items:     decodeItems(t.Items),
		CreatedAt: t.CreatedAt,
	}
}

func (h *ChecklistTemplateHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListChecklistTemplates(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]checklistTemplateResponse, 0, len(rows))
	for _, t := range rows {
		out = append(out, checklistTemplateFrom(t))
	}
	writeJSON(w, http.StatusOK, out)
}

type checklistTemplateBody struct {
	Name     string   `json:"name"`
	Category string   `json:"category"`
	Items    []string `json:"items"`
}

func (h *ChecklistTemplateHandler) create(w http.ResponseWriter, r *http.Request) {
	var b checklistTemplateBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	t, err := h.q.CreateChecklistTemplate(r.Context(), db.CreateChecklistTemplateParams{
		Name:      strings.TrimSpace(b.Name),
		Category:  strings.TrimSpace(b.Category),
		Items:     encode(cleanItems(b.Items)),
		CreatedBy: actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, checklistTemplateFrom(t))
}

func (h *ChecklistTemplateHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b checklistTemplateBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	t, err := h.q.UpdateChecklistTemplate(r.Context(), db.UpdateChecklistTemplateParams{
		ID:       id,
		Name:     strings.TrimSpace(b.Name),
		Category: strings.TrimSpace(b.Category),
		Items:    encode(cleanItems(b.Items)),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, checklistTemplateFrom(t))
}

func (h *ChecklistTemplateHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteChecklistTemplate(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// apply appends a template's items to a task's checklist.
func (h *ChecklistTemplateHandler) apply(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b struct {
		TaskID int64 `json:"task_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.TaskID == 0 {
		writeError(w, http.StatusBadRequest, errors.New("a task is required"))
		return
	}
	tpl, err := h.q.GetChecklistTemplate(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("template not found"))
		return
	}
	items := decodeItems(tpl.Items)
	pos, err := h.q.MaxChecklistPosition(r.Context(), b.TaskID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	added := 0
	for _, content := range items {
		pos++
		if _, err := h.q.CreateChecklistItem(r.Context(), db.CreateChecklistItemParams{
			TaskID:   b.TaskID,
			Content:  content,
			Position: pos,
		}); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		added++
	}
	writeJSON(w, http.StatusOK, map[string]any{"added": added})
}
