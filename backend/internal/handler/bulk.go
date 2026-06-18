package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// bulkBody is a multi-task action: apply Action to every task in IDs, using the
// action-specific Value (a bool for "done", a string for "status"/"priority",
// a nullable user id for "assignee", and ignored for "delete").
type bulkBody struct {
	IDs    []int64         `json:"ids"`
	Action string          `json:"action"`
	Value  json.RawMessage `json:"value"`
}

const maxBulkIDs = 500

// bulk applies one action across many tasks in a single statement.
func (h *TaskHandler) bulk(w http.ResponseWriter, r *http.Request) {
	var b bulkBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if len(b.IDs) == 0 {
		writeError(w, http.StatusBadRequest, errors.New("no task ids given"))
		return
	}
	if len(b.IDs) > maxBulkIDs {
		writeError(w, http.StatusBadRequest, errors.New("too many task ids"))
		return
	}

	ctx := r.Context()
	var err error
	switch b.Action {
	case "done":
		var done bool
		if jsonErr := json.Unmarshal(b.Value, &done); jsonErr != nil {
			writeError(w, http.StatusBadRequest, errors.New("value must be a boolean"))
			return
		}
		err = h.q.BulkSetTaskDone(ctx, db.BulkSetTaskDoneParams{Done: done, Ids: b.IDs})

	case "status":
		var status string
		if jsonErr := json.Unmarshal(b.Value, &status); jsonErr != nil || !h.statusExists(ctx, status) {
			writeError(w, http.StatusBadRequest, errors.New("invalid status"))
			return
		}
		err = h.q.BulkSetTaskStatus(ctx, db.BulkSetTaskStatusParams{Status: status, Ids: b.IDs})

	case "priority":
		var priority string
		if jsonErr := json.Unmarshal(b.Value, &priority); jsonErr != nil || !validPriority(priority) {
			writeError(w, http.StatusBadRequest, errors.New("invalid priority"))
			return
		}
		err = h.q.BulkSetTaskPriority(ctx, db.BulkSetTaskPriorityParams{Priority: priority, Ids: b.IDs})

	case "assignee":
		var assignee *int64
		if len(b.Value) > 0 {
			if jsonErr := json.Unmarshal(b.Value, &assignee); jsonErr != nil {
				writeError(w, http.StatusBadRequest, errors.New("value must be a user id or null"))
				return
			}
		}
		err = h.q.BulkSetTaskAssignee(ctx, db.BulkSetTaskAssigneeParams{Assignee: assignee, Ids: b.IDs})
		// Keep the assignee join table in sync (replace with the single value).
		var ids []int64
		if assignee != nil {
			ids = []int64{*assignee}
		}
		for _, tid := range b.IDs {
			h.setAssignees(ctx, tid, ids)
		}

	case "delete":
		err = h.q.BulkDeleteTasks(ctx, b.IDs)

	default:
		writeError(w, http.StatusBadRequest, errors.New("unknown action"))
		return
	}

	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	// A bulk schedule/status change can ripple to dependent tasks.
	if err := rescheduleAll(ctx, h.q); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{"updated": len(b.IDs)})
}
