package handler

import (
	"net/http"
	"time"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// ActivityHandler serves /api/v1/activity — the workspace-wide collaboration
// history: recent task events across the whole workspace in one timeline.
type ActivityHandler struct {
	q *db.Queries
}

// NewActivityHandler wires the handler to the query layer.
func NewActivityHandler(q *db.Queries) *ActivityHandler {
	return &ActivityHandler{q: q}
}

type feedActivityResponse struct {
	ID        int64     `json:"id"`
	TaskID    int64     `json:"task_id"`
	TaskTitle string    `json:"task_title"`
	ActorID   *int64    `json:"actor_id"`
	ActorName string    `json:"actor_name"`
	Action    string    `json:"action"`
	Detail    string    `json:"detail"`
	CreatedAt time.Time `json:"created_at"`
}

// List returns the most recent activity across the workspace, newest first.
func (h *ActivityHandler) List(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListRecentActivity(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]feedActivityResponse, 0, len(rows))
	for _, a := range rows {
		out = append(out, feedActivityResponse{
			ID:        a.ID,
			TaskID:    a.TaskID,
			TaskTitle: a.TaskTitle,
			ActorID:   a.ActorID,
			ActorName: a.ActorName,
			Action:    a.Action,
			Detail:    a.Detail,
			CreatedAt: a.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}
