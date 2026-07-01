package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// SkillHandler serves /api/v1/skills — the team skills matrix. Reading is open
// to any member; writes are scoped to the authenticated user's own skills.
type SkillHandler struct {
	q *db.Queries
}

// NewSkillHandler wires the handler to the query layer.
func NewSkillHandler(q *db.Queries) *SkillHandler {
	return &SkillHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/skills.
func (h *SkillHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Get("/me", h.mine)
	r.Post("/", h.upsert)
	r.Delete("/{id}", h.remove)
	return r
}

type skillResponse struct {
	ID       int64   `json:"id"`
	UserID   int64   `json:"user_id"`
	UserName string  `json:"user_name"`
	Avatar   *string `json:"avatar_url"`
	Skill    string  `json:"skill"`
	Level    int32   `json:"level"`
}

// list returns every member's skills for the matrix.
func (h *SkillHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListAllSkills(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]skillResponse, 0, len(rows))
	for _, s := range rows {
		out = append(out, skillResponse{
			ID:       s.ID,
			UserID:   s.UserID,
			UserName: s.UserName,
			Avatar:   avatarURLPtr(s.Avatar),
			Skill:    s.Skill,
			Level:    s.Level,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

// mine returns the current user's own skills.
func (h *SkillHandler) mine(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	rows, err := h.q.ListMySkills(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]skillResponse, 0, len(rows))
	for _, s := range rows {
		out = append(out, skillResponse{
			ID:     s.ID,
			UserID: s.UserID,
			Skill:  s.Skill,
			Level:  s.Level,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type skillBody struct {
	Skill string `json:"skill"`
	Level int32  `json:"level"`
}

// upsert adds or updates one of the current user's skills.
func (h *SkillHandler) upsert(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	var b skillBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Skill)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("skill is required"))
		return
	}
	level := b.Level
	if level < 1 {
		level = 1
	} else if level > 5 {
		level = 5
	}
	row, err := h.q.UpsertSkill(r.Context(), db.UpsertSkillParams{
		UserID: *actor,
		Skill:  name,
		Level:  level,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, skillResponse{
		ID:     row.ID,
		UserID: row.UserID,
		Skill:  row.Skill,
		Level:  row.Level,
	})
}

// remove deletes one of the current user's skills.
func (h *SkillHandler) remove(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteSkill(r.Context(), db.DeleteSkillParams{
		ID: id, UserID: *actor,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
