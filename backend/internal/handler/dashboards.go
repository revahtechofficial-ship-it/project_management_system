package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// DashboardHandler serves /api/v1/dashboards — saved, shareable dashboards.
// A dashboard is a named set of widget keys plus a visibility.
type DashboardHandler struct {
	q *db.Queries
}

// NewDashboardHandler wires the handler to the query layer.
func NewDashboardHandler(q *db.Queries) *DashboardHandler {
	return &DashboardHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/dashboards.
func (h *DashboardHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{id}", h.get)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

type dashboardResponse struct {
	ID         int64     `json:"id"`
	Name       string    `json:"name"`
	OwnerID    *int64    `json:"owner_id"`
	OwnerName  string    `json:"owner_name"`
	Visibility string    `json:"visibility"`
	Widgets    []string  `json:"widgets"`
	CanManage  bool      `json:"can_manage"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// decodeWidgets parses the stored JSON array of widget keys, tolerating junk.
func decodeWidgets(s string) []string {
	out := []string{}
	if s == "" {
		return out
	}
	_ = json.Unmarshal([]byte(s), &out)
	if out == nil {
		out = []string{}
	}
	return out
}

func owns(actor, owner *int64) bool {
	return actor != nil && owner != nil && *actor == *owner
}

func (h *DashboardHandler) list(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	admin := isAdmin(r.Context())
	rows, err := h.q.ListDashboards(r.Context(), actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]dashboardResponse, 0, len(rows))
	for _, d := range rows {
		out = append(out, dashboardResponse{
			ID:         d.ID,
			Name:       d.Name,
			OwnerID:    d.OwnerID,
			OwnerName:  d.OwnerName,
			Visibility: d.Visibility,
			Widgets:    decodeWidgets(d.Widgets),
			CanManage:  admin || owns(actor, d.OwnerID),
			CreatedAt:  d.CreatedAt,
			UpdatedAt:  d.UpdatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *DashboardHandler) get(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	d, err := h.q.GetDashboard(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("dashboard not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	actor := actorOf(r.Context())
	admin := isAdmin(r.Context())
	if d.Visibility != "workspace" && !owns(actor, d.OwnerID) && !admin {
		writeError(w, http.StatusForbidden, errors.New("this dashboard is private"))
		return
	}
	writeJSON(w, http.StatusOK, dashboardResponse{
		ID:         d.ID,
		Name:       d.Name,
		OwnerID:    d.OwnerID,
		OwnerName:  d.OwnerName,
		Visibility: d.Visibility,
		Widgets:    decodeWidgets(d.Widgets),
		CanManage:  admin || owns(actor, d.OwnerID),
		CreatedAt:  d.CreatedAt,
		UpdatedAt:  d.UpdatedAt,
	})
}

type dashboardBody struct {
	Name       string   `json:"name"`
	Visibility string   `json:"visibility"`
	Widgets    []string `json:"widgets"`
}

func normVisibility(v string) string {
	if v == "private" {
		return "private"
	}
	return "workspace"
}

func encodeWidgets(keys []string) string {
	if keys == nil {
		keys = []string{}
	}
	b, err := json.Marshal(keys)
	if err != nil {
		return "[]"
	}
	return string(b)
}

func (h *DashboardHandler) create(w http.ResponseWriter, r *http.Request) {
	var b dashboardBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a dashboard name is required"))
		return
	}
	actor := actorOf(r.Context())
	d, err := h.q.CreateDashboard(r.Context(), db.CreateDashboardParams{
		Name:       name,
		OwnerID:    actor,
		Visibility: normVisibility(b.Visibility),
		Widgets:    encodeWidgets(b.Widgets),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, dashboardResponse{
		ID:         d.ID,
		Name:       d.Name,
		OwnerID:    d.OwnerID,
		Visibility: d.Visibility,
		Widgets:    decodeWidgets(d.Widgets),
		CanManage:  true,
		CreatedAt:  d.CreatedAt,
		UpdatedAt:  d.UpdatedAt,
	})
}

// loadManageable fetches the {id} dashboard and confirms the actor owns it (or
// is an admin), writing the error response if not.
func (h *DashboardHandler) loadManageable(w http.ResponseWriter, r *http.Request) (db.GetDashboardRow, bool) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return db.GetDashboardRow{}, false
	}
	d, err := h.q.GetDashboard(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("dashboard not found"))
		return db.GetDashboardRow{}, false
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return db.GetDashboardRow{}, false
	}
	if !owns(actorOf(r.Context()), d.OwnerID) && !isAdmin(r.Context()) {
		writeError(w, http.StatusForbidden, errors.New("only the owner or an admin can change this dashboard"))
		return db.GetDashboardRow{}, false
	}
	return d, true
}

func (h *DashboardHandler) update(w http.ResponseWriter, r *http.Request) {
	d, ok := h.loadManageable(w, r)
	if !ok {
		return
	}
	var b dashboardBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a dashboard name is required"))
		return
	}
	if err := h.q.UpdateDashboard(r.Context(), db.UpdateDashboardParams{
		ID:         d.ID,
		Name:       name,
		Visibility: normVisibility(b.Visibility),
		Widgets:    encodeWidgets(b.Widgets),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *DashboardHandler) delete(w http.ResponseWriter, r *http.Request) {
	d, ok := h.loadManageable(w, r)
	if !ok {
		return
	}
	if err := h.q.DeleteDashboard(r.Context(), d.ID); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
