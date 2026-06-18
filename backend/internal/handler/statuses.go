package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// StatusHandler serves /api/v1/statuses — the customizable task workflow
// states (columns on the board). Reads are open to any authenticated user;
// writes are admin-only.
type StatusHandler struct {
	q *db.Queries
}

// NewStatusHandler wires the handler to the query layer.
func NewStatusHandler(q *db.Queries) *StatusHandler {
	return &StatusHandler{q: q}
}

// Routes builds a sub-router intended to be mounted under /api/v1/statuses.
func (h *StatusHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Post("/reorder", h.reorder)
	r.Post("/template", h.applyTemplate)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

type statusResponse struct {
	ID        int64  `json:"id"`
	Key       string `json:"key"`
	Label     string `json:"label"`
	Color     string `json:"color"`
	Position  int32  `json:"position"`
	Protected bool   `json:"protected"`
}

func statusFromModel(s db.TaskStatus) statusResponse {
	return statusResponse{
		ID: s.ID, Key: s.Key, Label: s.Label, Color: s.Color,
		Position: s.Position, Protected: s.Protected,
	}
}

func (h *StatusHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListStatuses(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]statusResponse, 0, len(rows))
	for _, s := range rows {
		out = append(out, statusFromModel(s))
	}
	writeJSON(w, http.StatusOK, out)
}

var (
	hexColor    = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)
	slugNonWord = regexp.MustCompile(`[^a-z0-9]+`)
)

// slugify turns a label into a stable, url-safe status key.
func slugify(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	s = slugNonWord.ReplaceAllString(s, "_")
	s = strings.Trim(s, "_")
	if s == "" {
		s = "status"
	}
	if len(s) > 40 {
		s = s[:40]
	}
	return s
}

// uniqueKey returns base, or base_2, base_3, … — the first key not yet taken.
func (h *StatusHandler) uniqueKey(ctx context.Context, base string) string {
	key := base
	for i := 2; ; i++ {
		if ok, err := h.q.StatusKeyExists(ctx, key); err != nil || !ok {
			return key
		}
		key = base + "_" + strconv.Itoa(i)
	}
}

// normColor validates a #rrggbb color, falling back to a neutral slate.
func normColor(c string) string {
	c = strings.TrimSpace(c)
	if !hexColor.MatchString(c) {
		return "#64748b"
	}
	return strings.ToLower(c)
}

type statusBody struct {
	Label    string `json:"label"`
	Color    string `json:"color"`
	Position int32  `json:"position"`
}

func (h *StatusHandler) create(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b statusBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	label := strings.TrimSpace(b.Label)
	if label == "" {
		writeError(w, http.StatusBadRequest, errors.New("label is required"))
		return
	}
	pos, err := h.q.MaxStatusPosition(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	s, err := h.q.CreateStatus(r.Context(), db.CreateStatusParams{
		Key:      h.uniqueKey(r.Context(), slugify(label)),
		Label:    label,
		Color:    normColor(b.Color),
		Position: pos + 1,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, statusFromModel(s))
}

func (h *StatusHandler) update(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b statusBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	label := strings.TrimSpace(b.Label)
	if label == "" {
		writeError(w, http.StatusBadRequest, errors.New("label is required"))
		return
	}
	s, err := h.q.UpdateStatus(r.Context(), db.UpdateStatusParams{
		ID: id, Label: label, Color: normColor(b.Color), Position: b.Position,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("status not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, statusFromModel(s))
}

func (h *StatusHandler) delete(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	s, err := h.q.GetStatus(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("status not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if s.Protected {
		writeError(w, http.StatusBadRequest, errors.New("this status can't be deleted"))
		return
	}
	if n, err := h.q.CountTasksWithStatus(r.Context(), s.Key); err == nil && n > 0 {
		writeError(w, http.StatusBadRequest,
			errors.New("move its tasks to another status first"))
		return
	}
	if err := h.q.DeleteStatus(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type reorderBody struct {
	IDs []int64 `json:"ids"`
}

func (h *StatusHandler) reorder(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b reorderBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	for i, id := range b.IDs {
		_ = h.q.SetStatusPosition(r.Context(), db.SetStatusPositionParams{
			ID: id, Position: int32(i),
		})
	}
	h.list(w, r)
}

// statusTemplates are ready-made workflows. Applying one adds any of its
// statuses that don't already exist (matched by key); nothing is removed.
var statusTemplates = map[string][]db.CreateStatusParams{
	"simple": {
		{Key: "todo", Label: "To Do", Color: "#0ea5e9"},
		{Key: "in_progress", Label: "In Progress", Color: "#6366f1"},
		{Key: "done", Label: "Done", Color: "#22c55e"},
	},
	"kanban": {
		{Key: "backlog", Label: "Backlog", Color: "#64748b"},
		{Key: "todo", Label: "To Do", Color: "#0ea5e9"},
		{Key: "in_progress", Label: "In Progress", Color: "#6366f1"},
		{Key: "review", Label: "Review", Color: "#8b5cf6"},
		{Key: "done", Label: "Done", Color: "#22c55e"},
	},
	"bug": {
		{Key: "open", Label: "Open", Color: "#ef4444"},
		{Key: "in_progress", Label: "In Progress", Color: "#6366f1"},
		{Key: "in_review", Label: "In Review", Color: "#8b5cf6"},
		{Key: "resolved", Label: "Resolved", Color: "#22c55e"},
		{Key: "closed", Label: "Closed", Color: "#64748b"},
	},
	"content": {
		{Key: "idea", Label: "Idea", Color: "#64748b"},
		{Key: "writing", Label: "Writing", Color: "#0ea5e9"},
		{Key: "editing", Label: "Editing", Color: "#6366f1"},
		{Key: "review", Label: "Review", Color: "#8b5cf6"},
		{Key: "published", Label: "Published", Color: "#22c55e"},
	},
}

type templateBody struct {
	Template string `json:"template"`
}

func (h *StatusHandler) applyTemplate(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b templateBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	tpl, ok := statusTemplates[b.Template]
	if !ok {
		writeError(w, http.StatusBadRequest, errors.New("unknown template"))
		return
	}
	pos, _ := h.q.MaxStatusPosition(r.Context())
	for _, s := range tpl {
		if exists, err := h.q.StatusKeyExists(r.Context(), s.Key); err == nil && exists {
			continue
		}
		pos++
		_, _ = h.q.CreateStatus(r.Context(), db.CreateStatusParams{
			Key: s.Key, Label: s.Label, Color: s.Color, Position: pos,
		})
	}
	h.list(w, r)
}
