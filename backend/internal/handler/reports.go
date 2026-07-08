package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// ReportHandler serves /api/v1/reports — saved custom report definitions
// (chosen columns + filters). The report itself is run client-side; the server
// only persists the definitions.
type ReportHandler struct {
	q *db.Queries
}

// NewReportHandler wires the handler to the query layer.
func NewReportHandler(q *db.Queries) *ReportHandler {
	return &ReportHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/reports.
func (h *ReportHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

type reportResponse struct {
	ID        int64           `json:"id"`
	Name      string          `json:"name"`
	Config    json.RawMessage `json:"config"`
	CreatedAt time.Time       `json:"created_at"`
}

func reportFrom(r db.SavedReport) reportResponse {
	config := json.RawMessage(r.Config)
	if len(strings.TrimSpace(r.Config)) == 0 {
		config = json.RawMessage("{}")
	}
	return reportResponse{
		ID:        r.ID,
		Name:      r.Name,
		Config:    config,
		CreatedAt: r.CreatedAt,
	}
}

func (h *ReportHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListSavedReports(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]reportResponse, 0, len(rows))
	for _, rp := range rows {
		out = append(out, reportFrom(rp))
	}
	writeJSON(w, http.StatusOK, out)
}

type reportBody struct {
	Name   string          `json:"name"`
	Config json.RawMessage `json:"config"`
}

func (b reportBody) configString() string {
	if len(b.Config) == 0 {
		return "{}"
	}
	return string(b.Config)
}

func (h *ReportHandler) create(w http.ResponseWriter, r *http.Request) {
	var b reportBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	row, err := h.q.CreateSavedReport(r.Context(), db.CreateSavedReportParams{
		Name:      strings.TrimSpace(b.Name),
		Config:    b.configString(),
		CreatedBy: actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, reportFrom(row))
}

func (h *ReportHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b reportBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	row, err := h.q.UpdateSavedReport(r.Context(), db.UpdateSavedReportParams{
		ID:     id,
		Name:   strings.TrimSpace(b.Name),
		Config: b.configString(),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, reportFrom(row))
}

func (h *ReportHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteSavedReport(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
