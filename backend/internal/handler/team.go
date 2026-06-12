package handler

import (
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

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
	writeJSON(w, http.StatusOK, members)
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
