package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

type retroResponse struct {
	ID         int64     `json:"id"`
	SprintID   int64     `json:"sprint_id"`
	Kind       string    `json:"kind"`
	Body       string    `json:"body"`
	AuthorName string    `json:"author_name"`
	Done       bool      `json:"done"`
	CreatedAt  time.Time `json:"created_at"`
}

func validRetroKind(s string) string {
	switch s {
	case "start", "stop", "continue", "action":
		return s
	default:
		return "start"
	}
}

func (h *SprintHandler) listRetro(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	rows, err := h.q.ListRetroItems(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]retroResponse, 0, len(rows))
	for _, it := range rows {
		out = append(out, retroResponse{
			ID:         it.ID,
			SprintID:   it.SprintID,
			Kind:       it.Kind,
			Body:       it.Body,
			AuthorName: it.AuthorName,
			Done:       it.Done,
			CreatedAt:  it.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type addRetroBody struct {
	Kind string `json:"kind"`
	Body string `json:"body"`
}

func (h *SprintHandler) addRetro(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b addRetroBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Body) == "" {
		writeError(w, http.StatusBadRequest, errors.New("body is required"))
		return
	}
	item, err := h.q.AddRetroItem(r.Context(), db.AddRetroItemParams{
		SprintID: id,
		AuthorID: actorOf(r.Context()),
		Kind:     validRetroKind(b.Kind),
		Body:     strings.TrimSpace(b.Body),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, retroResponse{
		ID:        item.ID,
		SprintID:  item.SprintID,
		Kind:      item.Kind,
		Body:      item.Body,
		Done:      item.Done,
		CreatedAt: item.CreatedAt,
	})
}

func retroItemID(r *http.Request) (int64, error) {
	return strconv.ParseInt(chi.URLParam(r, "itemId"), 10, 64)
}

type updateRetroBody struct {
	Done *bool `json:"done"`
}

func (h *SprintHandler) updateRetro(w http.ResponseWriter, r *http.Request) {
	id, err := retroItemID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b updateRetroBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Done != nil {
		if err := h.q.SetRetroDone(r.Context(), db.SetRetroDoneParams{
			ID: id, Done: *b.Done,
		}); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *SprintHandler) deleteRetro(w http.ResponseWriter, r *http.Request) {
	id, err := retroItemID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteRetroItem(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
