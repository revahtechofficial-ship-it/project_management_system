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
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// --- engine ----------------------------------------------------------------

type autoCondition struct {
	Field string `json:"field"`
	Op    string `json:"op"`
	Value string `json:"value"`
}

type autoAction struct {
	Type  string `json:"type"`
	Value string `json:"value"`
}

func idStr(p *int64) string {
	if p == nil {
		return ""
	}
	return strconv.FormatInt(*p, 10)
}

func autoFieldValue(t db.Task, field string) string {
	switch field {
	case "status":
		return t.Status
	case "priority":
		return t.Priority
	case "project":
		return idStr(t.ProjectID)
	case "sprint":
		return idStr(t.SprintID)
	case "has_assignee":
		if t.AssigneeID != nil {
			return "yes"
		}
		return "no"
	case "has_due":
		if t.DueDate.Valid {
			return "yes"
		}
		return "no"
	case "is_overdue":
		if t.DueDate.Valid && t.DueDate.Time.Before(time.Now()) {
			return "yes"
		}
		return "no"
	case "assignee":
		return idStr(t.AssigneeID)
	default:
		return ""
	}
}

func conditionsMatch(conds []autoCondition, t db.Task) bool {
	for _, c := range conds {
		actual := autoFieldValue(t, c.Field)
		switch c.Op {
		case "is_not":
			if actual == c.Value {
				return false
			}
		default: // "is"
			if actual != c.Value {
				return false
			}
		}
	}
	return true
}

func applyAutoActions(ctx context.Context, q *db.Queries, t db.Task, acts []autoAction) {
	for _, a := range acts {
		switch a.Type {
		case "set_status":
			_, _ = q.SetTaskStatus(ctx, db.SetTaskStatusParams{ID: t.ID, Status: a.Value})
		case "set_priority":
			_ = q.SetTaskPriority(ctx, db.SetTaskPriorityParams{ID: t.ID, Priority: a.Value})
		case "add_tag":
			if a.Value != "" {
				_ = q.AddTaskTag(ctx, db.AddTaskTagParams{ID: t.ID, Tag: a.Value})
			}
		case "assign":
			if uid, err := strconv.ParseInt(a.Value, 10, 64); err == nil {
				_ = q.AddTaskAssignee(ctx, db.AddTaskAssigneeParams{TaskID: t.ID, UserID: uid})
				notifyUser(ctx, q, uid, "assigned", "You were assigned a task", t.Title, "/tasks")
			}
		case "move_to_sprint":
			if sid, err := strconv.ParseInt(a.Value, 10, 64); err == nil {
				s := sid
				_ = q.SetTaskSprint(ctx, db.SetTaskSprintParams{ID: t.ID, SprintID: &s})
			}
		case "clear_sprint":
			_ = q.SetTaskSprint(ctx, db.SetTaskSprintParams{ID: t.ID, SprintID: nil})
		case "set_due_in_days":
			if n, err := strconv.Atoi(a.Value); err == nil {
				due := time.Now().AddDate(0, 0, n)
				_ = q.SetTaskDueAt(ctx, db.SetTaskDueAtParams{
					ID:      t.ID,
					DueDate: pgtype.Timestamptz{Time: due, Valid: true},
				})
			}
		case "notify_assignee":
			if t.AssigneeID != nil {
				notifyUser(ctx, q, *t.AssigneeID, "task", "Task automation", t.Title, "/tasks")
			}
		case "reassign":
			if uid, err := strconv.ParseInt(a.Value, 10, 64); err == nil {
				_ = q.ClearTaskAssignees(ctx, t.ID)
				_ = q.AddTaskAssignee(ctx, db.AddTaskAssigneeParams{TaskID: t.ID, UserID: uid})
				notifyUser(ctx, q, uid, "assigned", "You were assigned a task", t.Title, "/tasks")
			}
		case "unassign":
			_ = q.ClearTaskAssignees(ctx, t.ID)
		case "notify_user":
			if uid, err := strconv.ParseInt(a.Value, 10, 64); err == nil {
				notifyUser(ctx, q, uid, "task", "Task automation", t.Title, "/tasks")
			}
		}
	}
}

// runAutomations evaluates the enabled rules for a trigger against a task and
// applies their actions. Actions update the task directly and do NOT re-trigger
// automations, so there is no recursion.
func runAutomations(ctx context.Context, q *db.Queries, taskID int64, trigger string) {
	rules, err := q.ListEnabledRulesByTrigger(ctx, trigger)
	if err != nil || len(rules) == 0 {
		return
	}
	task, err := q.GetTask(ctx, taskID)
	if err != nil {
		return
	}
	for _, rule := range rules {
		var conds []autoCondition
		_ = json.Unmarshal([]byte(rule.Conditions), &conds)
		if !conditionsMatch(conds, task) {
			continue
		}
		var acts []autoAction
		_ = json.Unmarshal([]byte(rule.Actions), &acts)
		applyAutoActions(ctx, q, task, acts)
	}
}

// --- CRUD handler ----------------------------------------------------------

// AutomationHandler serves /api/v1/automations — the rule-based automation
// builder (trigger + conditions + actions).
type AutomationHandler struct {
	q *db.Queries
}

// NewAutomationHandler wires the handler to the query layer.
func NewAutomationHandler(q *db.Queries) *AutomationHandler {
	return &AutomationHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/automations.
func (h *AutomationHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Patch("/{id}/enabled", h.setEnabled)
	r.Delete("/{id}", h.delete)
	return r
}

type ruleResponse struct {
	ID         int64           `json:"id"`
	Name       string          `json:"name"`
	Enabled    bool            `json:"enabled"`
	Trigger    string          `json:"trigger"`
	Conditions []autoCondition `json:"conditions"`
	Actions    []autoAction    `json:"actions"`
	CreatedAt  time.Time       `json:"created_at"`
	UpdatedAt  time.Time       `json:"updated_at"`
}

func ruleFrom(r db.AutomationRule) ruleResponse {
	conds := []autoCondition{}
	acts := []autoAction{}
	_ = json.Unmarshal([]byte(r.Conditions), &conds)
	_ = json.Unmarshal([]byte(r.Actions), &acts)
	return ruleResponse{
		ID:         r.ID,
		Name:       r.Name,
		Enabled:    r.Enabled,
		Trigger:    r.Trigger,
		Conditions: conds,
		Actions:    acts,
		CreatedAt:  r.CreatedAt,
		UpdatedAt:  r.UpdatedAt,
	}
}

func (h *AutomationHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListAutomationRules(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]ruleResponse, 0, len(rows))
	for _, rule := range rows {
		out = append(out, ruleFrom(rule))
	}
	writeJSON(w, http.StatusOK, out)
}

type ruleBody struct {
	Name       string          `json:"name"`
	Enabled    bool            `json:"enabled"`
	Trigger    string          `json:"trigger"`
	Conditions []autoCondition `json:"conditions"`
	Actions    []autoAction    `json:"actions"`
}

func normTrigger(t string) string {
	switch t {
	case "task_created", "status_changed", "task_completed", "assignee_changed":
		return t
	default:
		return "task_created"
	}
}

func encode(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return "[]"
	}
	return string(b)
}

func (h *AutomationHandler) create(w http.ResponseWriter, r *http.Request) {
	var b ruleBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	rule, err := h.q.CreateAutomationRule(r.Context(), db.CreateAutomationRuleParams{
		Name:       strings.TrimSpace(b.Name),
		Enabled:    b.Enabled,
		Trigger:    normTrigger(b.Trigger),
		Conditions: encode(b.Conditions),
		Actions:    encode(b.Actions),
		CreatedBy:  actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, ruleFrom(rule))
}

func (h *AutomationHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b ruleBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.q.UpdateAutomationRule(r.Context(), db.UpdateAutomationRuleParams{
		ID:         id,
		Name:       strings.TrimSpace(b.Name),
		Enabled:    b.Enabled,
		Trigger:    normTrigger(b.Trigger),
		Conditions: encode(b.Conditions),
		Actions:    encode(b.Actions),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AutomationHandler) setEnabled(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b struct {
		Enabled bool `json:"enabled"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.q.SetAutomationRuleEnabled(r.Context(), db.SetAutomationRuleEnabledParams{
		ID: id, Enabled: b.Enabled,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AutomationHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteAutomationRule(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
