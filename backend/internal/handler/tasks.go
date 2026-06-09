// Package handler contains the HTTP handlers that expose the backend's REST API.
package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// TaskHandler serves the /api/v1/tasks resource.
type TaskHandler struct {
	q *db.Queries
}

// NewTaskHandler wires the handler to the generated query layer.
func NewTaskHandler(q *db.Queries) *TaskHandler {
	return &TaskHandler{q: q}
}

// Routes builds a sub-router intended to be mounted under /api/v1/tasks.
func (h *TaskHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{id}", h.get)
	r.Patch("/{id}", h.setDone)
	r.Delete("/{id}", h.delete)
	return r
}

func (h *TaskHandler) list(w http.ResponseWriter, r *http.Request) {
	tasks, err := h.q.ListTasks(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, tasks)
}

type createTaskBody struct {
	Title       string `json:"title"`
	Description string `json:"description"`
}

func (h *TaskHandler) create(w http.ResponseWriter, r *http.Request) {
	var body createTaskBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if body.Title == "" {
		writeError(w, http.StatusBadRequest, errors.New("title is required"))
		return
	}
	task, err := h.q.CreateTask(r.Context(), db.CreateTaskParams{
		Title:       body.Title,
		Description: body.Description,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, task)
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
	writeJSON(w, http.StatusOK, task)
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
	task, err := h.q.SetTaskDone(r.Context(), db.SetTaskDoneParams{ID: id, Done: body.Done})
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("task not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, task)
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

func idParam(r *http.Request) (int64, error) {
	return strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
}
