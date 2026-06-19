package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// PageHandler serves /api/v1/pages — collaborative Docs, Whiteboards and Forms.
// One table backs all three; the `type` field selects the editor on the client.
type PageHandler struct {
	q *db.Queries
}

// NewPageHandler wires the handler to the query layer.
func NewPageHandler(q *db.Queries) *PageHandler {
	return &PageHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/pages.
func (h *PageHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{id}", h.get)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

type pageResponse struct {
	ID            int64     `json:"id"`
	Type          string    `json:"type"`
	Title         string    `json:"title"`
	Icon          string    `json:"icon"`
	Body          string    `json:"body"`
	CreatedByName string    `json:"created_by_name"`
	UpdatedByName string    `json:"updated_by_name"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

func pageFromList(p db.ListPagesRow) pageResponse {
	return pageResponse{
		ID:            p.ID,
		Type:          p.Type,
		Title:         p.Title,
		Icon:          p.Icon,
		CreatedByName: p.CreatedByName,
		UpdatedByName: p.UpdatedByName,
		CreatedAt:     p.CreatedAt,
		UpdatedAt:     p.UpdatedAt,
	}
}

func pageFromGet(p db.GetPageRow) pageResponse {
	return pageResponse{
		ID:            p.ID,
		Type:          p.Type,
		Title:         p.Title,
		Icon:          p.Icon,
		Body:          p.Body,
		CreatedByName: p.CreatedByName,
		UpdatedByName: p.UpdatedByName,
		CreatedAt:     p.CreatedAt,
		UpdatedAt:     p.UpdatedAt,
	}
}

// normPageType keeps the type to the three supported kinds, defaulting to doc.
func normPageType(t string) string {
	switch t {
	case "doc", "whiteboard", "form":
		return t
	default:
		return "doc"
	}
}

func (h *PageHandler) list(w http.ResponseWriter, r *http.Request) {
	pageType := normPageType(r.URL.Query().Get("type"))
	rows, err := h.q.ListPages(r.Context(), pageType)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]pageResponse, 0, len(rows))
	for _, p := range rows {
		out = append(out, pageFromList(p))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *PageHandler) get(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	row, err := h.q.GetPage(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("page not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, pageFromGet(row))
}

type pageBody struct {
	Type  string `json:"type"`
	Title string `json:"title"`
	Icon  string `json:"icon"`
	Body  string `json:"body"`
}

func (h *PageHandler) create(w http.ResponseWriter, r *http.Request) {
	var b pageBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	actor := actorOf(r.Context())
	p, err := h.q.CreatePage(r.Context(), db.CreatePageParams{
		Type:      normPageType(b.Type),
		Title:     strings.TrimSpace(b.Title),
		Icon:      strings.TrimSpace(b.Icon),
		Body:      b.Body,
		CreatedBy: actor,
		UpdatedBy: actor,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	// Reload with author names so the client gets a complete record.
	row, err := h.q.GetPage(r.Context(), p.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, pageFromGet(row))
}

func (h *PageHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b pageBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.q.UpdatePage(r.Context(), db.UpdatePageParams{
		ID:        id,
		Title:     strings.TrimSpace(b.Title),
		Icon:      strings.TrimSpace(b.Icon),
		Body:      b.Body,
		UpdatedBy: actorOf(r.Context()),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	row, err := h.q.GetPage(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, pageFromGet(row))
}

func (h *PageHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	row, err := h.q.GetPage(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	// Only the page's creator or an admin may delete it.
	actor := actorOf(r.Context())
	owns := actor != nil && row.CreatedBy != nil && *row.CreatedBy == *actor
	if !owns && !isAdmin(r.Context()) {
		writeError(w, http.StatusForbidden, errors.New("only the author or an admin can delete this page"))
		return
	}
	if err := h.q.DeletePage(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
