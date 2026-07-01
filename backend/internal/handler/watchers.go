package handler

import (
	"context"
	"errors"
	"net/http"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// watch adds the current user as a watcher of a task.
func (h *TaskHandler) watch(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	if err := h.q.AddWatcher(r.Context(), db.AddWatcherParams{
		TaskID: id, UserID: *actor,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"watching": true})
}

// unwatch removes the current user as a watcher of a task.
func (h *TaskHandler) unwatch(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	if err := h.q.RemoveWatcher(r.Context(), db.RemoveWatcherParams{
		TaskID: id, UserID: *actor,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"watching": false})
}

// watchers reports whether the current user follows a task and how many do.
func (h *TaskHandler) watchers(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	count, err := h.q.CountWatchers(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	watching := false
	if actor := actorOf(r.Context()); actor != nil {
		watching, _ = h.q.IsWatching(r.Context(), db.IsWatchingParams{
			TaskID: id, UserID: *actor,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"count": count, "watching": watching,
	})
}

// watching returns the ids of tasks the current user follows.
func (h *TaskHandler) watching(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	ids, err := h.q.WatchedTaskIDs(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if ids == nil {
		ids = []int64{}
	}
	writeJSON(w, http.StatusOK, ids)
}

// skipActor returns a set pre-seeded with the acting user, so fan-out helpers
// don't notify the person who triggered the event.
func skipActor(ctx context.Context) map[int64]bool {
	skip := map[int64]bool{}
	if a := actorOf(ctx); a != nil {
		skip[*a] = true
	}
	return skip
}

// notifyWatchers delivers an in-app notification to every watcher of a task,
// skipping any ids in [skip] (best-effort; failures are swallowed).
func (h *TaskHandler) notifyWatchers(ctx context.Context, taskID int64,
	skip map[int64]bool, typ, title, body string) {
	ids, err := h.q.WatcherIDs(ctx, taskID)
	if err != nil {
		return
	}
	for _, uid := range ids {
		if skip[uid] {
			continue
		}
		notifyUser(ctx, h.q, uid, typ, title, body, "/tasks")
	}
}
