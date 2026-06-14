package handler

import (
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// CustomFieldHandler serves the /api/v1/custom-fields resource: workspace-wide
// user-defined field definitions for tasks.
type CustomFieldHandler struct {
	q *db.Queries
}

// NewCustomFieldHandler wires the handler to the generated query layer.
func NewCustomFieldHandler(q *db.Queries) *CustomFieldHandler {
	return &CustomFieldHandler{q: q}
}

// Routes builds a sub-router intended to be mounted under
// /api/v1/custom-fields.
func (h *CustomFieldHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

type customFieldResponse struct {
	ID      int64    `json:"id"`
	Name    string   `json:"name"`
	Type    string   `json:"type"`
	Options []string `json:"options"`
}

func customFieldFrom(f db.CustomField) customFieldResponse {
	opts := f.Options
	if opts == nil {
		opts = []string{}
	}
	return customFieldResponse{
		ID: f.ID, Name: f.Name, Type: f.FieldType, Options: opts,
	}
}

var validFieldTypes = map[string]bool{
	"text": true, "number": true, "date": true, "select": true, "checkbox": true,
}

type customFieldBody struct {
	Name    string   `json:"name"`
	Type    string   `json:"type"`
	Options []string `json:"options"`
}

// sanitizeOptions trims, drops blanks and caps the option list.
func sanitizeOptions(in []string) []string {
	out := make([]string, 0, len(in))
	for _, o := range in {
		o = strings.TrimSpace(o)
		if o != "" {
			out = append(out, o)
		}
		if len(out) >= 50 {
			break
		}
	}
	return out
}

func (h *CustomFieldHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListCustomFields(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]customFieldResponse, 0, len(rows))
	for _, f := range rows {
		out = append(out, customFieldFrom(f))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *CustomFieldHandler) create(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b customFieldBody
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a field name is required"))
		return
	}
	if !validFieldTypes[b.Type] {
		writeError(w, http.StatusBadRequest, errors.New("invalid field type"))
		return
	}
	f, err := h.q.CreateCustomField(r.Context(), db.CreateCustomFieldParams{
		Name:      name,
		FieldType: b.Type,
		Options:   sanitizeOptions(b.Options),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, customFieldFrom(f))
}

func (h *CustomFieldHandler) update(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b customFieldBody
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a field name is required"))
		return
	}
	f, err := h.q.UpdateCustomField(r.Context(), db.UpdateCustomFieldParams{
		ID:      id,
		Name:    name,
		Options: sanitizeOptions(b.Options),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, customFieldFrom(f))
}

func (h *CustomFieldHandler) delete(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteCustomField(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
