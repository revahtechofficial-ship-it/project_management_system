package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// actorOf returns the authenticated user's id for activity attribution.
func actorOf(ctx context.Context) *int64 {
	if c, ok := account.FromContext(ctx); ok {
		id := c.UserID
		return &id
	}
	return nil
}

// logActivity records a task event on a best-effort basis.
func logActivity(ctx context.Context, q *db.Queries, taskID int64,
	action, detail string) {
	_ = q.CreateActivity(ctx, db.CreateActivityParams{
		TaskID:  taskID,
		ActorID: actorOf(ctx),
		Action:  action,
		Detail:  detail,
	})
}

func (h *TaskHandler) listComments(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	rows, err := h.q.ListComments(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, rows)
}

type commentBody struct {
	Body     string  `json:"body"`
	Mentions []int64 `json:"mentions"`
}

func (h *TaskHandler) createComment(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b commentBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	body := strings.TrimSpace(b.Body)
	if body == "" {
		writeError(w, http.StatusBadRequest, errors.New("comment is empty"))
		return
	}
	comment, err := h.q.CreateComment(r.Context(), db.CreateCommentParams{
		TaskID:   id,
		AuthorID: actorOf(r.Context()),
		Body:     body,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	logActivity(r.Context(), h.q, id, "comment", "")
	h.notifyOnComment(r.Context(), id, body, b.Mentions)
	writeJSON(w, http.StatusCreated, comment)
}

// notifyOnComment notifies each mentioned user, plus the task's assignee about
// a new comment on their task — skipping the commenter and avoiding a duplicate
// when the assignee was also mentioned.
func (h *TaskHandler) notifyOnComment(ctx context.Context, taskID int64,
	body string, mentions []int64) {
	actor := actorOf(ctx)
	mentioned := make(map[int64]bool, len(mentions))
	for _, m := range mentions {
		if actor != nil && *actor == m {
			continue
		}
		mentioned[m] = true
		notifyUser(ctx, h.q, m, "mention",
			"You were mentioned in a comment", body, "/tasks")
	}
	t, err := h.q.GetTask(ctx, taskID)
	if err != nil || t.AssigneeID == nil {
		return
	}
	a := *t.AssigneeID
	if mentioned[a] || (actor != nil && *actor == a) {
		return
	}
	notifyUser(ctx, h.q, a, "comment", "New comment on your task", t.Title, "/tasks")
}

func (h *TaskHandler) deleteComment(w http.ResponseWriter, r *http.Request) {
	cid, err := commentParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	comment, err := h.q.GetComment(r.Context(), cid)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("comment not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	c, _ := account.FromContext(r.Context())
	isAuthor := comment.AuthorID != nil && *comment.AuthorID == c.UserID
	if !isAuthor && !isAdmin(r.Context()) {
		writeError(w, http.StatusForbidden,
			errors.New("only the author or an admin can delete this comment"))
		return
	}
	if err := h.q.DeleteComment(r.Context(), cid); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *TaskHandler) listActivity(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	rows, err := h.q.ListActivity(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, rows)
}

func commentParam(r *http.Request) (int64, error) {
	return strconv.ParseInt(chi.URLParam(r, "commentId"), 10, 64)
}
