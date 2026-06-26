package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// ReleaseHandler serves /api/v1/releases — Release Planning: named versions
// with a target date and status that tasks can be assigned to.
type ReleaseHandler struct {
	q *db.Queries
}

// NewReleaseHandler wires the handler to the query layer.
func NewReleaseHandler(q *db.Queries) *ReleaseHandler {
	return &ReleaseHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/releases.
func (h *ReleaseHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

type releaseResponse struct {
	ID         int64   `json:"id"`
	Name       string  `json:"name"`
	Version    string  `json:"version"`
	Status     string  `json:"status"`
	TargetDate *string `json:"target_date"`
	Notes      string  `json:"notes"`
}

func dateStrPtr(d pgtype.Date) *string {
	if !d.Valid {
		return nil
	}
	s := d.Time.Format(dateLayout)
	return &s
}

func parseDatePtr(s *string) pgtype.Date {
	if s == nil || *s == "" {
		return pgtype.Date{}
	}
	t, err := time.Parse(dateLayout, *s)
	if err != nil {
		return pgtype.Date{}
	}
	return pgtype.Date{Time: t, Valid: true}
}

func normReleaseStatus(s string) string {
	switch s {
	case "planned", "in_progress", "released":
		return s
	default:
		return "planned"
	}
}

func (h *ReleaseHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListReleases(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]releaseResponse, 0, len(rows))
	for _, rel := range rows {
		out = append(out, releaseResponse{
			ID:         rel.ID,
			Name:       rel.Name,
			Version:    rel.Version,
			Status:     rel.Status,
			TargetDate: dateStrPtr(rel.TargetDate),
			Notes:      rel.Notes,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type releaseBody struct {
	Name       string  `json:"name"`
	Version    string  `json:"version"`
	Status     string  `json:"status"`
	TargetDate *string `json:"target_date"`
	Notes      string  `json:"notes"`
}

func (h *ReleaseHandler) create(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b releaseBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	rel, err := h.q.CreateRelease(r.Context(), db.CreateReleaseParams{
		Name:       strings.TrimSpace(b.Name),
		Version:    strings.TrimSpace(b.Version),
		Status:     normReleaseStatus(b.Status),
		TargetDate: parseDatePtr(b.TargetDate),
		Notes:      b.Notes,
		CreatedBy:  actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, releaseResponse{
		ID:         rel.ID,
		Name:       rel.Name,
		Version:    rel.Version,
		Status:     rel.Status,
		TargetDate: dateStrPtr(rel.TargetDate),
		Notes:      rel.Notes,
	})
}

func (h *ReleaseHandler) update(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b releaseBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.q.UpdateRelease(r.Context(), db.UpdateReleaseParams{
		ID:         id,
		Name:       strings.TrimSpace(b.Name),
		Version:    strings.TrimSpace(b.Version),
		Status:     normReleaseStatus(b.Status),
		TargetDate: parseDatePtr(b.TargetDate),
		Notes:      b.Notes,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ReleaseHandler) delete(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteRelease(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
