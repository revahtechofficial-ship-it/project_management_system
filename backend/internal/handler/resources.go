package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// ResourceHandler serves /api/v1/resources — Resource Management: per-member
// weekly capacity and availability (time off), the persistent inputs that the
// client combines with live task data to plan workload and allocation.
type ResourceHandler struct {
	q *db.Queries
}

// NewResourceHandler wires the handler to the query layer.
func NewResourceHandler(q *db.Queries) *ResourceHandler {
	return &ResourceHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/resources.
func (h *ResourceHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/capacity", h.listCapacity)
	r.Put("/capacity/{userId}", h.setCapacity)
	r.Get("/availability", h.listAvailability)
	r.Post("/availability", h.createAvailability)
	r.Delete("/availability/{id}", h.deleteAvailability)
	return r
}

const dateLayout = "2006-01-02"

// --- capacity --------------------------------------------------------------

type capacityResponse struct {
	UserID      int64  `json:"user_id"`
	Name        string `json:"name"`
	Email       string `json:"email"`
	WeeklyHours int32  `json:"weekly_hours"`
}

func (h *ResourceHandler) listCapacity(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListCapacity(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]capacityResponse, 0, len(rows))
	for _, c := range rows {
		out = append(out, capacityResponse{
			UserID:      c.UserID,
			Name:        c.FullName,
			Email:       c.Email,
			WeeklyHours: c.WeeklyHours,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ResourceHandler) setCapacity(w http.ResponseWriter, r *http.Request) {
	userID, err := strconv.ParseInt(chi.URLParam(r, "userId"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid user id"))
		return
	}
	var b struct {
		WeeklyHours int32 `json:"weekly_hours"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	hours := b.WeeklyHours
	if hours < 0 {
		hours = 0
	}
	if hours > 168 {
		hours = 168
	}
	if err := h.q.SetCapacity(r.Context(), db.SetCapacityParams{
		UserID:      userID,
		WeeklyHours: hours,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- availability ----------------------------------------------------------

type availabilityResponse struct {
	ID        int64  `json:"id"`
	UserID    int64  `json:"user_id"`
	UserName  string `json:"user_name"`
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
	Kind      string `json:"kind"`
	Note      string `json:"note"`
}

func (h *ResourceHandler) listAvailability(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListAvailability(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]availabilityResponse, 0, len(rows))
	for _, a := range rows {
		out = append(out, availabilityResponse{
			ID:        a.ID,
			UserID:    a.UserID,
			UserName:  a.UserName,
			StartDate: a.StartDate.Time.Format(dateLayout),
			EndDate:   a.EndDate.Time.Format(dateLayout),
			Kind:      a.Kind,
			Note:      a.Note,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ResourceHandler) createAvailability(w http.ResponseWriter, r *http.Request) {
	var b struct {
		UserID    int64  `json:"user_id"`
		StartDate string `json:"start_date"`
		EndDate   string `json:"end_date"`
		Kind      string `json:"kind"`
		Note      string `json:"note"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.UserID == 0 {
		writeError(w, http.StatusBadRequest, errors.New("a team member is required"))
		return
	}
	start, err := time.Parse(dateLayout, b.StartDate)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid start date"))
		return
	}
	end, err := time.Parse(dateLayout, b.EndDate)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid end date"))
		return
	}
	if end.Before(start) {
		end = start
	}
	id, err := h.q.CreateAvailability(r.Context(), db.CreateAvailabilityParams{
		UserID:    b.UserID,
		StartDate: pgtype.Date{Time: start, Valid: true},
		EndDate:   pgtype.Date{Time: end, Valid: true},
		Kind:      normKind(b.Kind),
		Note:      b.Note,
		CreatedBy: actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"id": id})
}

func (h *ResourceHandler) deleteAvailability(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteAvailability(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func normKind(k string) string {
	switch k {
	case "vacation", "sick", "holiday", "other":
		return k
	default:
		return "other"
	}
}
