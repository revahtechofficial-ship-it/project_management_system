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

// BudgetHandler serves /api/v1/budgets — a spending cap per project, with
// actual cost rolled up from approved expenses and billable time.
type BudgetHandler struct {
	q *db.Queries
}

// NewBudgetHandler wires the handler to the query layer.
func NewBudgetHandler(q *db.Queries) *BudgetHandler {
	return &BudgetHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/budgets.
func (h *BudgetHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Put("/", h.upsert)
	r.Delete("/{id}", h.delete)
	return r
}

type budgetResponse struct {
	ID              int64  `json:"id"`
	ProjectID       int64  `json:"project_id"`
	ProjectName     string `json:"project_name"`
	AmountCents     int64  `json:"amount_cents"`
	HourlyRateCents int64  `json:"hourly_rate_cents"`
	Notes           string `json:"notes"`
	ExpenseCents    int64  `json:"expense_cents"`
	BillableMinutes int64  `json:"billable_minutes"`
	LaborCents      int64  `json:"labor_cents"`
	ActualCents     int64  `json:"actual_cents"`
	UpdatedAt       string `json:"updated_at"`
}

func (h *BudgetHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListBudgets(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]budgetResponse, 0, len(rows))
	for _, b := range rows {
		labor := b.BillableMinutes * b.HourlyRateCents / 60
		out = append(out, budgetResponse{
			ID:              b.ID,
			ProjectID:       b.ProjectID,
			ProjectName:     b.ProjectName,
			AmountCents:     b.AmountCents,
			HourlyRateCents: b.HourlyRateCents,
			Notes:           b.Notes,
			ExpenseCents:    b.ExpenseCents,
			BillableMinutes: b.BillableMinutes,
			LaborCents:      labor,
			ActualCents:     b.ExpenseCents + labor,
			UpdatedAt:       b.UpdatedAt.Format(time.RFC3339),
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type budgetBody struct {
	ProjectID       int64  `json:"project_id"`
	AmountCents     int64  `json:"amount_cents"`
	HourlyRateCents int64  `json:"hourly_rate_cents"`
	Notes           string `json:"notes"`
}

func (h *BudgetHandler) upsert(w http.ResponseWriter, r *http.Request) {
	var b budgetBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.ProjectID == 0 {
		writeError(w, http.StatusBadRequest, errors.New("a project is required"))
		return
	}
	if b.AmountCents < 0 || b.HourlyRateCents < 0 {
		writeError(w, http.StatusBadRequest, errors.New("amounts must be positive"))
		return
	}
	row, err := h.q.UpsertBudget(r.Context(), db.UpsertBudgetParams{
		ProjectID:       b.ProjectID,
		AmountCents:     b.AmountCents,
		HourlyRateCents: b.HourlyRateCents,
		Notes:           strings.TrimSpace(b.Notes),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, budgetResponse{
		ID:              row.ID,
		ProjectID:       row.ProjectID,
		AmountCents:     row.AmountCents,
		HourlyRateCents: row.HourlyRateCents,
		Notes:           row.Notes,
		UpdatedAt:       row.UpdatedAt.Format(time.RFC3339),
	})
}

func (h *BudgetHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteBudget(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
