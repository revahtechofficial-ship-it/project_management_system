package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// IncidentHandler serves /api/v1/incidents — the bug and incident tracker,
// with a severity + triage-status workflow and assignment.
type IncidentHandler struct {
	q *db.Queries
}

// NewIncidentHandler wires the handler to the query layer.
func NewIncidentHandler(q *db.Queries) *IncidentHandler {
	return &IncidentHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/incidents.
func (h *IncidentHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Patch("/{id}/status", h.setStatus)
	r.Delete("/{id}", h.delete)
	return r
}

type incidentResponse struct {
	ID           int64      `json:"id"`
	Title        string     `json:"title"`
	Description  string     `json:"description"`
	Kind         string     `json:"kind"`
	Severity     string     `json:"severity"`
	Status       string     `json:"status"`
	ProjectID    *int64     `json:"project_id"`
	ProjectName  string     `json:"project_name"`
	AssigneeID   *int64     `json:"assignee_id"`
	AssigneeName string     `json:"assignee_name"`
	ReporterID   *int64     `json:"reporter_id"`
	ReporterName string     `json:"reporter_name"`
	Component    string     `json:"component"`
	ResolvedAt   *time.Time `json:"resolved_at"`
	CreatedAt    time.Time  `json:"created_at"`
}

func validIncidentKind(s string) string {
	switch s {
	case "bug", "incident":
		return s
	default:
		return "bug"
	}
}

func validSeverity(s string) string {
	switch s {
	case "critical", "high", "medium", "low":
		return s
	default:
		return "medium"
	}
}

func validIncidentStatus(s string) bool {
	switch s {
	case "open", "investigating", "mitigated", "resolved", "closed":
		return true
	default:
		return false
	}
}

func (h *IncidentHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListIncidents(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]incidentResponse, 0, len(rows))
	for _, i := range rows {
		out = append(out, incidentResponse{
			ID:           i.ID,
			Title:        i.Title,
			Description:  i.Description,
			Kind:         i.Kind,
			Severity:     i.Severity,
			Status:       i.Status,
			ProjectID:    i.ProjectID,
			ProjectName:  i.ProjectName,
			AssigneeID:   i.AssigneeID,
			AssigneeName: i.AssigneeName,
			ReporterID:   i.ReporterID,
			ReporterName: i.ReporterName,
			Component:    i.Component,
			ResolvedAt:   tsPtr(i.ResolvedAt),
			CreatedAt:    i.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type incidentBody struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Kind        string `json:"kind"`
	Severity    string `json:"severity"`
	ProjectID   *int64 `json:"project_id"`
	AssigneeID  *int64 `json:"assignee_id"`
	Component   string `json:"component"`
}

func (h *IncidentHandler) create(w http.ResponseWriter, r *http.Request) {
	var b incidentBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Title) == "" {
		writeError(w, http.StatusBadRequest, errors.New("title is required"))
		return
	}
	row, err := h.q.CreateIncident(r.Context(), db.CreateIncidentParams{
		Title:       strings.TrimSpace(b.Title),
		Description: strings.TrimSpace(b.Description),
		Kind:        validIncidentKind(b.Kind),
		Severity:    validSeverity(b.Severity),
		ProjectID:   b.ProjectID,
		AssigneeID:  b.AssigneeID,
		ReporterID:  actorOf(r.Context()),
		Component:   strings.TrimSpace(b.Component),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	actor := actorOf(r.Context())
	if row.AssigneeID != nil && (actor == nil || *row.AssigneeID != *actor) {
		notifyUser(r.Context(), h.q, *row.AssigneeID, "incident",
			"Assigned: "+row.Title,
			actorName(r.Context())+" assigned you a "+row.Severity+" "+row.Kind,
			"/incidents")
	}
	writeJSON(w, http.StatusCreated, incidentFromRow(row))
}

func (h *IncidentHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b incidentBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Title) == "" {
		writeError(w, http.StatusBadRequest, errors.New("title is required"))
		return
	}
	row, err := h.q.UpdateIncident(r.Context(), db.UpdateIncidentParams{
		ID:          id,
		Title:       strings.TrimSpace(b.Title),
		Description: strings.TrimSpace(b.Description),
		Kind:        validIncidentKind(b.Kind),
		Severity:    validSeverity(b.Severity),
		ProjectID:   b.ProjectID,
		AssigneeID:  b.AssigneeID,
		Component:   strings.TrimSpace(b.Component),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, incidentFromRow(row))
}

type incidentStatusBody struct {
	Status string `json:"status"`
}

func (h *IncidentHandler) setStatus(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b incidentStatusBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if !validIncidentStatus(b.Status) {
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
		return
	}
	// Stamp the resolution time when the incident lands in a closed state.
	resolved := pgtype.Timestamptz{}
	if b.Status == "resolved" || b.Status == "closed" {
		resolved = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	row, err := h.q.SetIncidentStatus(r.Context(), db.SetIncidentStatusParams{
		ID:         id,
		Status:     b.Status,
		ResolvedAt: resolved,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	actor := actorOf(r.Context())
	if row.AssigneeID != nil && (actor == nil || *row.AssigneeID != *actor) {
		notifyUser(r.Context(), h.q, *row.AssigneeID, "incident",
			row.Title+" is now "+b.Status,
			actorName(r.Context())+" moved \""+row.Title+"\" to "+b.Status,
			"/incidents")
	}
	writeJSON(w, http.StatusOK, incidentFromRow(row))
}

func (h *IncidentHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteIncident(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// incidentFromRow maps a mutation's returned row (no joins) to the API shape;
// the client refreshes the list to pick up assignee, reporter and project.
func incidentFromRow(i db.Incident) incidentResponse {
	return incidentResponse{
		ID:          i.ID,
		Title:       i.Title,
		Description: i.Description,
		Kind:        i.Kind,
		Severity:    i.Severity,
		Status:      i.Status,
		ProjectID:   i.ProjectID,
		AssigneeID:  i.AssigneeID,
		ReporterID:  i.ReporterID,
		Component:   i.Component,
		ResolvedAt:  tsPtr(i.ResolvedAt),
		CreatedAt:   i.CreatedAt,
	}
}
