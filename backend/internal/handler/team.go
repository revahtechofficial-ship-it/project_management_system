package handler

import (
	"net/http"

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
