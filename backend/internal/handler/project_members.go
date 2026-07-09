package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// Per-project roles. A manager administers the project (settings, membership);
// an editor works in it; a viewer is read-only.
const (
	roleViewer  = "viewer"
	roleEditor  = "editor"
	roleManager = "manager"
)

func validProjectRole(s string) string {
	switch s {
	case roleViewer, roleEditor, roleManager:
		return s
	default:
		return roleEditor
	}
}

// projectRoleFor resolves the caller's effective role on a project.
//
// Workspace owners/admins always manage. An explicit member gets their role.
// A project with no members stays open to everyone (exactly the behaviour from
// before per-project roles existed), so adding roles never locks anyone out of
// an existing project; once membership is defined, non-members are read-only.
func (h *ProjectHandler) projectRoleFor(ctx context.Context, projectID int64) string {
	if isAdmin(ctx) {
		return roleManager
	}
	actor := actorOf(ctx)
	if actor == nil {
		return roleViewer
	}
	role, err := h.q.GetProjectMemberRole(ctx, db.GetProjectMemberRoleParams{
		ProjectID: projectID,
		UserID:    *actor,
	})
	if err == nil {
		return validProjectRole(role)
	}
	if n, cerr := h.q.CountProjectMembers(ctx, projectID); cerr == nil && n == 0 {
		return roleManager
	}
	return roleViewer
}

// requireProjectManager writes a 403 unless the caller manages the project.
func (h *ProjectHandler) requireProjectManager(w http.ResponseWriter,
	r *http.Request, projectID int64) bool {
	if h.projectRoleFor(r.Context(), projectID) != roleManager {
		writeError(w, http.StatusForbidden,
			errors.New("project manager access required"))
		return false
	}
	return true
}

type projectMemberResponse struct {
	UserID    int64     `json:"user_id"`
	UserName  string    `json:"user_name"`
	UserEmail string    `json:"user_email"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"created_at"`
}

type projectMembersResponse struct {
	MyRole  string                  `json:"my_role"`
	Members []projectMemberResponse `json:"members"`
}

// listMembers returns a project's members and the caller's effective role.
func (h *ProjectHandler) listMembers(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	rows, err := h.q.ListProjectMembers(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	members := make([]projectMemberResponse, 0, len(rows))
	for _, m := range rows {
		members = append(members, projectMemberResponse{
			UserID:    m.UserID,
			UserName:  m.UserName,
			UserEmail: m.UserEmail,
			Role:      m.Role,
			CreatedAt: m.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, projectMembersResponse{
		MyRole:  h.projectRoleFor(r.Context(), id),
		Members: members,
	})
}

func memberUserID(r *http.Request) (int64, error) {
	return strconv.ParseInt(chi.URLParam(r, "userId"), 10, 64)
}

// setMember adds a member or changes their role (managers only).
func (h *ProjectHandler) setMember(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if !h.requireProjectManager(w, r, id) {
		return
	}
	userID, err := memberUserID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid user id"))
		return
	}
	var b struct {
		Role string `json:"role"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.q.UpsertProjectMember(r.Context(), db.UpsertProjectMemberParams{
		ProjectID: id,
		UserID:    userID,
		Role:      validProjectRole(b.Role),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// removeMember drops a member from a project (managers only).
func (h *ProjectHandler) removeMember(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if !h.requireProjectManager(w, r, id) {
		return
	}
	userID, err := memberUserID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid user id"))
		return
	}
	if err := h.q.DeleteProjectMember(r.Context(), db.DeleteProjectMemberParams{
		ProjectID: id,
		UserID:    userID,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
