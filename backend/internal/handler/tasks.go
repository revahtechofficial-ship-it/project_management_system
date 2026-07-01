// Package handler contains the HTTP handlers that expose the backend's REST API.
package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// TaskHandler serves the /api/v1/tasks resource.
type TaskHandler struct {
	q   *db.Queries
	dir string
}

// NewTaskHandler wires the handler to the generated query layer. dir is the
// directory where file attachments are stored.
func NewTaskHandler(q *db.Queries, dir string) *TaskHandler {
	return &TaskHandler{q: q, dir: dir}
}

// Routes builds a sub-router intended to be mounted under /api/v1/tasks.
func (h *TaskHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Post("/bulk", h.bulk)
	r.Get("/watching", h.watching)
	r.Get("/{id}", h.get)
	r.Post("/{id}/watch", h.watch)
	r.Delete("/{id}/watch", h.unwatch)
	r.Get("/{id}/watchers", h.watchers)
	r.Put("/{id}", h.update)
	r.Patch("/{id}", h.setDone)
	r.Patch("/{id}/status", h.setStatus)
	r.Patch("/{id}/sprint", h.setSprint)
	r.Delete("/{id}", h.delete)
	r.Get("/{id}/subtasks", h.listSubtasks)
	r.Get("/{id}/checklist", h.listChecklist)
	r.Post("/{id}/checklist", h.createChecklist)
	r.Patch("/checklist/{itemId}", h.setChecklistDone)
	r.Delete("/checklist/{itemId}", h.deleteChecklistItem)
	r.Get("/{id}/comments", h.listComments)
	r.Post("/{id}/comments", h.createComment)
	r.Delete("/comments/{commentId}", h.deleteComment)
	r.Get("/{id}/activity", h.listActivity)
	r.Get("/{id}/attachments", h.listAttachments)
	r.Post("/{id}/attachments", h.uploadAttachment)
	r.Get("/{id}/fields", h.listTaskFields)
	r.Put("/{id}/fields/{fieldId}", h.setTaskField)
	return r
}

// taskResponse is the clean JSON shape the frontend consumes — nullable dates
// become RFC3339 (or null) instead of pgtype's verbose struct form.
type taskResponse struct {
	ID               int64      `json:"id"`
	Title            string     `json:"title"`
	Description      string     `json:"description"`
	Done             bool       `json:"done"`
	Status           string     `json:"status"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
	ProjectID        *int64     `json:"project_id"`
	AssigneeID       *int64     `json:"assignee_id"`
	ProjectName      *string    `json:"project_name"`
	AssigneeName     *string    `json:"assignee_name"`
	StartDate        *time.Time `json:"start_date"`
	DueDate          *time.Time `json:"due_date"`
	ParentID         *int64     `json:"parent_id"`
	Recurrence       string     `json:"recurrence"`
	SubtaskCount     int32      `json:"subtask_count"`
	SubtaskDoneCount int32      `json:"subtask_done_count"`
	BaselineStart    *time.Time `json:"baseline_start"`
	BaselineDue      *time.Time `json:"baseline_due"`
	Priority         string     `json:"priority"`
	Tags             []string   `json:"tags"`
	EstimateMinutes  int32      `json:"estimate_minutes"`
	SprintID         *int64     `json:"sprint_id"`
	Points           int32      `json:"points"`
	IssueType        string     `json:"issue_type"`
	Severity         string     `json:"severity"`
	ReleaseID        *int64     `json:"release_id"`
	AssigneeIDs      []int64    `json:"assignee_ids"`
	AssigneeNames    []string   `json:"assignee_names"`
}

func taskFromModel(t db.Task) taskResponse {
	return taskResponse{
		ID:              t.ID,
		Title:           t.Title,
		Description:     t.Description,
		Done:            t.Done,
		Status:          t.Status,
		CreatedAt:       t.CreatedAt,
		UpdatedAt:       t.UpdatedAt,
		ProjectID:       t.ProjectID,
		AssigneeID:      t.AssigneeID,
		StartDate:       tsPtr(t.StartDate),
		DueDate:         tsPtr(t.DueDate),
		ParentID:        t.ParentID,
		Recurrence:      t.Recurrence,
		BaselineStart:   tsPtr(t.BaselineStart),
		BaselineDue:     tsPtr(t.BaselineDue),
		Priority:        t.Priority,
		Tags:            t.Tags,
		EstimateMinutes: t.EstimateMinutes,
		SprintID:        t.SprintID,
		Points:          t.Points,
		IssueType:       t.IssueType,
		Severity:        t.Severity,
		ReleaseID:       t.ReleaseID,
		AssigneeIDs:     []int64{},
		AssigneeNames:   []string{},
	}
}

func taskFromRow(r db.ListTasksRow) taskResponse {
	return taskResponse{
		ID:               r.ID,
		Title:            r.Title,
		Description:      r.Description,
		Done:             r.Done,
		Status:           r.Status,
		CreatedAt:        r.CreatedAt,
		UpdatedAt:        r.UpdatedAt,
		ProjectID:        r.ProjectID,
		AssigneeID:       r.AssigneeID,
		ProjectName:      r.ProjectName,
		AssigneeName:     r.AssigneeName,
		StartDate:        tsPtr(r.StartDate),
		DueDate:          tsPtr(r.DueDate),
		ParentID:         r.ParentID,
		Recurrence:       r.Recurrence,
		SubtaskCount:     r.SubtaskCount,
		SubtaskDoneCount: r.SubtaskDoneCount,
		BaselineStart:    tsPtr(r.BaselineStart),
		BaselineDue:      tsPtr(r.BaselineDue),
		Priority:         r.Priority,
		Tags:             r.Tags,
		EstimateMinutes:  r.EstimateMinutes,
		SprintID:         r.SprintID,
		Points:           r.Points,
		IssueType:        r.IssueType,
		Severity:         r.Severity,
		ReleaseID:        r.ReleaseID,
		AssigneeIDs:      r.AssigneeIds,
		AssigneeNames:    r.AssigneeNames,
	}
}

// clampPoints keeps story points sane (0..1000).
func clampPoints(p int32) int32 {
	if p < 0 {
		return 0
	}
	if p > 1000 {
		return 1000
	}
	return p
}

// taskWithAssignees builds a single-task response and fills its full assignee
// list (ids + names) from the join table.
func (h *TaskHandler) taskWithAssignees(ctx context.Context, t db.Task) taskResponse {
	resp := taskFromModel(t)
	if rows, err := h.q.ListTaskAssignees(ctx, t.ID); err == nil {
		ids := make([]int64, 0, len(rows))
		names := make([]string, 0, len(rows))
		for _, a := range rows {
			ids = append(ids, a.UserID)
			names = append(names, a.FullName)
		}
		resp.AssigneeIDs = ids
		resp.AssigneeNames = names
	}
	return resp
}

// resolveAssignees derives the full (deduped, positive) assignee list and the
// denormalized primary from a request body. The new assignee_ids field wins;
// assignee_id is a single-value fallback for older callers. A present-but-empty
// assignee_ids explicitly clears all assignees.
func resolveAssignees(b taskBody) (primary *int64, ids []int64) {
	src := b.AssigneeIDs
	if src == nil && b.AssigneeID != nil {
		src = []int64{*b.AssigneeID}
	}
	seen := make(map[int64]bool)
	for _, id := range src {
		if id <= 0 || seen[id] {
			continue
		}
		seen[id] = true
		ids = append(ids, id)
	}
	if len(ids) > 0 {
		p := ids[0]
		primary = &p
	}
	return primary, ids
}

// setAssignees replaces a task's assignee join rows with ids.
func (h *TaskHandler) setAssignees(ctx context.Context, taskID int64, ids []int64) {
	_ = h.q.ClearTaskAssignees(ctx, taskID)
	for _, id := range ids {
		_ = h.q.AddTaskAssignee(ctx, db.AddTaskAssigneeParams{TaskID: taskID, UserID: id})
	}
}

// clampEstimate keeps the estimate non-negative and within a sane ceiling
// (1000 hours), so a bad client value can't poison the column.
func clampEstimate(m int32) int32 {
	if m < 0 {
		return 0
	}
	if m > 60000 {
		return 60000
	}
	return m
}

func validPriority(s string) bool {
	switch s {
	case "none", "low", "normal", "high", "urgent":
		return true
	default:
		return false
	}
}

func priorityOrNone(s string) string {
	if s == "" {
		return "none"
	}
	return s
}

// sanitizeTags trims, drops blanks, de-duplicates, and caps tags so the column
// stays clean. Always returns a non-nil slice.
func sanitizeTags(in []string) []string {
	out := make([]string, 0, len(in))
	seen := make(map[string]bool)
	for _, t := range in {
		t = strings.TrimSpace(t)
		if t == "" || seen[strings.ToLower(t)] {
			continue
		}
		if len(t) > 30 {
			t = t[:30]
		}
		seen[strings.ToLower(t)] = true
		out = append(out, t)
		if len(out) >= 20 {
			break
		}
	}
	return out
}

// SetBaseline snapshots every task's current start/due dates as its baseline,
// so the timeline can later show planned-vs-actual drift.
func (h *TaskHandler) SetBaseline(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	if err := h.q.SetBaseline(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// statusExists reports whether key names a real, customizable workflow status.
func (h *TaskHandler) statusExists(ctx context.Context, key string) bool {
	ok, err := h.q.StatusKeyExists(ctx, key)
	return err == nil && ok
}

func statusOrTodo(s string) string {
	if s == "" {
		return "todo"
	}
	return s
}

func validRecurrence(s string) bool {
	switch s {
	case "none", "daily", "weekly", "monthly":
		return true
	default:
		return false
	}
}

func recurrenceOrNone(s string) string {
	if s == "" {
		return "none"
	}
	return s
}

func addPeriod(t time.Time, rec string) time.Time {
	switch rec {
	case "daily":
		return t.AddDate(0, 0, 1)
	case "weekly":
		return t.AddDate(0, 0, 7)
	case "monthly":
		return t.AddDate(0, 1, 0)
	default:
		return t
	}
}

// spawnNext creates the next occurrence of a completed recurring (top-level)
// task, shifting its dates by one period. Best-effort.
func (h *TaskHandler) spawnNext(ctx context.Context, t db.Task) {
	if !validRecurrence(t.Recurrence) || t.Recurrence == "none" {
		return
	}
	if t.ParentID != nil {
		return
	}
	shift := func(ts pgtype.Timestamptz) pgtype.Timestamptz {
		if !ts.Valid {
			return ts
		}
		return pgtype.Timestamptz{Time: addPeriod(ts.Time, t.Recurrence), Valid: true}
	}
	next, err := h.q.CreateTask(ctx, db.CreateTaskParams{
		Title:           t.Title,
		Description:     t.Description,
		ProjectID:       t.ProjectID,
		AssigneeID:      t.AssigneeID,
		StartDate:       shift(t.StartDate),
		DueDate:         shift(t.DueDate),
		Status:          "todo",
		Recurrence:      t.Recurrence,
		Priority:        t.Priority,
		Tags:            t.Tags,
		EstimateMinutes: t.EstimateMinutes,
		SprintID:        t.SprintID,
		Points:          t.Points,
		IssueType:       t.IssueType,
		Severity:        t.Severity,
		ReleaseID:       t.ReleaseID,
	})
	if err != nil {
		return
	}
	// Carry over every assignee to the new occurrence and notify them.
	if rows, e := h.q.ListTaskAssignees(ctx, t.ID); e == nil {
		for _, a := range rows {
			_ = h.q.AddTaskAssignee(ctx, db.AddTaskAssigneeParams{
				TaskID: next.ID, UserID: a.UserID,
			})
			notifyUser(ctx, h.q, a.UserID, "assigned",
				"Recurring task scheduled", next.Title, "/tasks")
		}
	}
}

func (h *TaskHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListTasks(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]taskResponse, 0, len(rows))
	for _, row := range rows {
		out = append(out, taskFromRow(row))
	}
	writeJSON(w, http.StatusOK, out)
}

type taskBody struct {
	Title           string   `json:"title"`
	Description     string   `json:"description"`
	ProjectID       *int64   `json:"project_id"`
	AssigneeID      *int64   `json:"assignee_id"`
	AssigneeIDs     []int64  `json:"assignee_ids"`
	StartDate       *string  `json:"start_date"`
	DueDate         *string  `json:"due_date"`
	Status          string   `json:"status"`
	ParentID        *int64   `json:"parent_id"`
	Recurrence      string   `json:"recurrence"`
	Priority        string   `json:"priority"`
	Tags            []string `json:"tags"`
	EstimateMinutes int32    `json:"estimate_minutes"`
	SprintID        *int64   `json:"sprint_id"`
	Points          int32    `json:"points"`
	IssueType       string   `json:"issue_type"`
	Severity        string   `json:"severity"`
	ReleaseID       *int64   `json:"release_id"`
}

func issueTypeOrDefault(s string) string {
	switch s {
	case "task", "bug", "story", "epic":
		return s
	default:
		return "task"
	}
}

func severityOrNone(s string) string {
	switch s {
	case "none", "minor", "major", "critical":
		return s
	default:
		return "none"
	}
}

func (h *TaskHandler) create(w http.ResponseWriter, r *http.Request) {
	var body taskBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if body.Title == "" {
		writeError(w, http.StatusBadRequest, errors.New("title is required"))
		return
	}
	start, due, err := parseSchedule(body)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	status := statusOrTodo(body.Status)
	if !h.statusExists(r.Context(), status) {
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
		return
	}
	recurrence := recurrenceOrNone(body.Recurrence)
	if !validRecurrence(recurrence) {
		writeError(w, http.StatusBadRequest, errors.New("invalid recurrence"))
		return
	}
	priority := priorityOrNone(body.Priority)
	if !validPriority(priority) {
		writeError(w, http.StatusBadRequest, errors.New("invalid priority"))
		return
	}
	primary, assignees := resolveAssignees(body)
	task, err := h.q.CreateTask(r.Context(), db.CreateTaskParams{
		Title:           body.Title,
		Description:     body.Description,
		ProjectID:       body.ProjectID,
		AssigneeID:      primary,
		StartDate:       start,
		DueDate:         due,
		Status:          status,
		ParentID:        body.ParentID,
		Recurrence:      recurrence,
		Priority:        priority,
		Tags:            sanitizeTags(body.Tags),
		EstimateMinutes: clampEstimate(body.EstimateMinutes),
		SprintID:        body.SprintID,
		Points:          clampPoints(body.Points),
		IssueType:       issueTypeOrDefault(body.IssueType),
		Severity:        severityOrNone(body.Severity),
		ReleaseID:       body.ReleaseID,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.setAssignees(r.Context(), task.ID, assignees)
	if task.ParentID == nil {
		logActivity(r.Context(), h.q, task.ID, "created", "")
	}
	for i := range assignees {
		notifyAssigned(r.Context(), h.q, &assignees[i], task.Title)
	}
	runAutomations(r.Context(), h.q, task.ID, "task_created")
	dispatchTaskEvent(h.q, "task.created", task.Title,
		actorName(r.Context()), "", task.ID)
	writeJSON(w, http.StatusCreated, h.taskWithAssignees(r.Context(), task))
}

func (h *TaskHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var body taskBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if body.Title == "" {
		writeError(w, http.StatusBadRequest, errors.New("title is required"))
		return
	}
	start, due, err := parseSchedule(body)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	status := statusOrTodo(body.Status)
	if !h.statusExists(r.Context(), status) {
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
		return
	}
	recurrence := recurrenceOrNone(body.Recurrence)
	if !validRecurrence(recurrence) {
		writeError(w, http.StatusBadRequest, errors.New("invalid recurrence"))
		return
	}
	priority := priorityOrNone(body.Priority)
	if !validPriority(priority) {
		writeError(w, http.StatusBadRequest, errors.New("invalid priority"))
		return
	}
	priorRows, _ := h.q.ListTaskAssignees(r.Context(), id)
	priorSet := make(map[int64]bool, len(priorRows))
	for _, a := range priorRows {
		priorSet[a.UserID] = true
	}
	primary, assignees := resolveAssignees(body)
	task, err := h.q.UpdateTask(r.Context(), db.UpdateTaskParams{
		ID:              id,
		Title:           body.Title,
		Description:     body.Description,
		ProjectID:       body.ProjectID,
		AssigneeID:      primary,
		StartDate:       start,
		DueDate:         due,
		Status:          status,
		Recurrence:      recurrence,
		Priority:        priority,
		Tags:            sanitizeTags(body.Tags),
		EstimateMinutes: clampEstimate(body.EstimateMinutes),
		SprintID:        body.SprintID,
		Points:          clampPoints(body.Points),
		IssueType:       issueTypeOrDefault(body.IssueType),
		Severity:        severityOrNone(body.Severity),
		ReleaseID:       body.ReleaseID,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("task not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.setAssignees(r.Context(), id, assignees)
	// A date change may ripple to dependent tasks; keep the schedule valid.
	if err := rescheduleAll(r.Context(), h.q); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	logActivity(r.Context(), h.q, id, "updated", "")
	for i := range assignees {
		if !priorSet[assignees[i]] {
			notifyAssigned(r.Context(), h.q, &assignees[i], task.Title)
		}
	}
	writeJSON(w, http.StatusOK, h.taskWithAssignees(r.Context(), task))
}

func (h *TaskHandler) get(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	task, err := h.q.GetTask(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("task not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, h.taskWithAssignees(r.Context(), task))
}

type setDoneBody struct {
	Done bool `json:"done"`
}

func (h *TaskHandler) setDone(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var body setDoneBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	prior, perr := h.q.GetTask(r.Context(), id)
	if errors.Is(perr, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("task not found"))
		return
	}
	if perr != nil {
		writeError(w, http.StatusInternalServerError, perr)
		return
	}
	task, err := h.q.SetTaskDone(r.Context(), db.SetTaskDoneParams{ID: id, Done: body.Done})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if body.Done && !prior.Done {
		h.spawnNext(r.Context(), task)
	}
	if body.Done != prior.Done {
		title := "A task you follow was reopened"
		if body.Done {
			logActivity(r.Context(), h.q, id, "completed", "")
			title = "A task you follow was completed"
		} else {
			logActivity(r.Context(), h.q, id, "reopened", "")
		}
		h.notifyWatchers(r.Context(), id, skipActor(r.Context()), "task",
			title, task.Title)
	}
	writeJSON(w, http.StatusOK, h.taskWithAssignees(r.Context(), task))
}

type setStatusBody struct {
	Status string `json:"status"`
}

func (h *TaskHandler) setStatus(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var body setStatusBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if !h.statusExists(r.Context(), body.Status) {
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
		return
	}
	prior, perr := h.q.GetTask(r.Context(), id)
	if errors.Is(perr, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("task not found"))
		return
	}
	if perr != nil {
		writeError(w, http.StatusInternalServerError, perr)
		return
	}
	task, err := h.q.SetTaskStatus(r.Context(), db.SetTaskStatusParams{
		ID: id, Status: body.Status,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if body.Status == "done" && !prior.Done {
		h.spawnNext(r.Context(), task)
	}
	watchTitle := "A task you follow was updated"
	if body.Status == "done" {
		logActivity(r.Context(), h.q, id, "completed", "")
		watchTitle = "A task you follow was completed"
	} else {
		logActivity(r.Context(), h.q, id, "status", body.Status)
	}
	if body.Status != prior.Status {
		h.notifyWatchers(r.Context(), id, skipActor(r.Context()), "task",
			watchTitle, task.Title)
	}
	runAutomations(r.Context(), h.q, id, "status_changed")
	if body.Status == "done" && !prior.Done {
		runAutomations(r.Context(), h.q, id, "task_completed")
	}
	if body.Status == "done" && !prior.Done {
		dispatchTaskEvent(h.q, "task.completed", task.Title,
			actorName(r.Context()), "", id)
	} else {
		dispatchTaskEvent(h.q, "task.updated", task.Title,
			actorName(r.Context()), body.Status, id)
	}
	writeJSON(w, http.StatusOK, h.taskWithAssignees(r.Context(), task))
}

type setSprintBody struct {
	SprintID *int64 `json:"sprint_id"`
}

// setSprint moves a task into a sprint (or back to the backlog when null) —
// the lightweight call used by sprint planning.
func (h *TaskHandler) setSprint(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b setSprintBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.q.SetTaskSprint(r.Context(), db.SetTaskSprintParams{
		ID: id, SprintID: b.SprintID,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	task, err := h.q.GetTask(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("task not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, h.taskWithAssignees(r.Context(), task))
}

func (h *TaskHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteTask(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// parseSchedule parses the optional start/due "YYYY-MM-DD" fields into nullable
// timestamptz values (reusing parseDue from the projects handler).
func parseSchedule(b taskBody) (start, due pgtype.Timestamptz, err error) {
	start, err = parseDue(b.StartDate)
	if err != nil {
		return start, due, errors.New("invalid start_date, expected YYYY-MM-DD")
	}
	due, err = parseDue(b.DueDate)
	if err != nil {
		return start, due, errors.New("invalid due_date, expected YYYY-MM-DD")
	}
	return start, due, nil
}

func (h *TaskHandler) listSubtasks(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	rows, err := h.q.ListSubtasks(r.Context(), &id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]taskResponse, 0, len(rows))
	for _, t := range rows {
		out = append(out, taskFromModel(t))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *TaskHandler) listChecklist(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	items, err := h.q.ListChecklist(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

type checklistBody struct {
	Content string `json:"content"`
}

func (h *TaskHandler) createChecklist(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b checklistBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Content == "" {
		writeError(w, http.StatusBadRequest, errors.New("content is required"))
		return
	}
	pos, err := h.q.MaxChecklistPosition(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	item, err := h.q.CreateChecklistItem(r.Context(), db.CreateChecklistItemParams{
		TaskID:   id,
		Content:  b.Content,
		Position: pos + 1,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, item)
}

type checklistDoneBody struct {
	Done bool `json:"done"`
}

func (h *TaskHandler) setChecklistDone(w http.ResponseWriter, r *http.Request) {
	id, err := itemParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b checklistDoneBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	item, err := h.q.SetChecklistItemDone(r.Context(), db.SetChecklistItemDoneParams{
		ID: id, Done: b.Done,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("item not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (h *TaskHandler) deleteChecklistItem(w http.ResponseWriter, r *http.Request) {
	id, err := itemParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteChecklistItem(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func idParam(r *http.Request) (int64, error) {
	return strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
}

func itemParam(r *http.Request) (int64, error) {
	return strconv.ParseInt(chi.URLParam(r, "itemId"), 10, 64)
}
