package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

type taskFieldValue struct {
	FieldID int64  `json:"field_id"`
	Value   string `json:"value"`
}

// listTaskFields returns a task's custom-field values.
func (h *TaskHandler) listTaskFields(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	rows, err := h.q.ListTaskFieldValues(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]taskFieldValue, 0, len(rows))
	for _, v := range rows {
		out = append(out, taskFieldValue{FieldID: v.FieldID, Value: v.Value})
	}
	writeJSON(w, http.StatusOK, out)
}

// setTaskField upserts (or clears, when empty) one custom-field value on a task.
func (h *TaskHandler) setTaskField(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	fieldID, err := strconv.ParseInt(chi.URLParam(r, "fieldId"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid field id"))
		return
	}
	var b struct {
		Value string `json:"value"`
	}
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	value := strings.TrimSpace(b.Value)
	if value == "" {
		if err := h.q.DeleteTaskFieldValue(r.Context(), db.DeleteTaskFieldValueParams{
			TaskID: id, FieldID: fieldID,
		}); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if err := h.q.SetTaskFieldValue(r.Context(), db.SetTaskFieldValueParams{
		TaskID: id, FieldID: fieldID, Value: value,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
