package handler

import (
	"errors"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

type teamMemberResponse struct {
	ID             int64     `json:"id"`
	Email          string    `json:"email"`
	FullName       string    `json:"full_name"`
	Role           string    `json:"role"`
	AvatarURL      *string   `json:"avatar_url"`
	OpenTasks      int32     `json:"open_tasks"`
	CompletedTasks int32     `json:"completed_tasks"`
	CreatedAt      time.Time `json:"created_at"`
}

// TeamHandler serves the /api/v1/team resource: the workspace's registered
// users with their aggregated task workload.
type TeamHandler struct {
	q *db.Queries
}

// NewTeamHandler wires the handler to the generated query layer.
func NewTeamHandler(q *db.Queries) *TeamHandler {
	return &TeamHandler{q: q}
}

// List returns every member (registered user) with open/completed task counts.
func (h *TeamHandler) List(w http.ResponseWriter, r *http.Request) {
	members, err := h.q.ListMembers(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]teamMemberResponse, 0, len(members))
	for _, m := range members {
		out = append(out, teamMemberResponse{
			ID:             m.ID,
			Email:          m.Email,
			FullName:       m.FullName,
			Role:           m.Role,
			AvatarURL:      avatarURLPtr(m.Avatar),
			OpenTasks:      m.OpenTasks,
			CompletedTasks: m.CompletedTasks,
			CreatedAt:      m.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type roleBody struct {
	Role string `json:"role"`
}

// SetRole changes a member's role (admin-only). The owner is immutable and the
// owner role is not assignable via the API.
func (h *TeamHandler) SetRole(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b roleBody
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Role != "admin" && b.Role != "member" {
		writeError(w, http.StatusBadRequest,
			errors.New("role must be 'admin' or 'member'"))
		return
	}
	target, err := h.q.GetUserByID(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("user not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if target.Role == "owner" {
		writeError(w, http.StatusForbidden,
			errors.New("the workspace owner's role cannot be changed"))
		return
	}
	u, err := h.q.SetUserRole(r.Context(),
		db.SetUserRoleParams{ID: id, Role: b.Role})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id": u.ID, "email": u.Email, "full_name": u.FullName, "role": u.Role,
	})
}
