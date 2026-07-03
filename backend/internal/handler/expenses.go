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

// ExpenseHandler serves /api/v1/expenses — expense claims submitted by the
// team, with a lightweight approve / reject / reimburse workflow.
type ExpenseHandler struct {
	q *db.Queries
}

// NewExpenseHandler wires the handler to the query layer.
func NewExpenseHandler(q *db.Queries) *ExpenseHandler {
	return &ExpenseHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/expenses.
func (h *ExpenseHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Patch("/{id}/status", h.setStatus)
	r.Delete("/{id}", h.delete)
	return r
}

type expenseResponse struct {
	ID            int64  `json:"id"`
	UserID        *int64 `json:"user_id"`
	SubmitterName string `json:"submitter_name"`
	ProjectID     *int64 `json:"project_id"`
	ProjectName   string `json:"project_name"`
	Category      string `json:"category"`
	AmountCents   int64  `json:"amount_cents"`
	SpentOn       string `json:"spent_on"`
	Description   string `json:"description"`
	Merchant      string `json:"merchant"`
	ReceiptURL    string `json:"receipt_url"`
	Status        string `json:"status"`
	CreatedAt     string `json:"created_at"`
}

func validExpenseCategory(s string) string {
	switch s {
	case "travel", "meals", "software", "hardware", "office",
		"subscriptions", "other":
		return s
	default:
		return "other"
	}
}

func validExpenseStatus(s string) bool {
	switch s {
	case "pending", "approved", "rejected", "reimbursed":
		return true
	default:
		return false
	}
}

func (h *ExpenseHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListExpenses(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]expenseResponse, 0, len(rows))
	for _, e := range rows {
		out = append(out, expenseResponse{
			ID:            e.ID,
			UserID:        e.UserID,
			SubmitterName: e.SubmitterName,
			ProjectID:     e.ProjectID,
			ProjectName:   e.ProjectName,
			Category:      e.Category,
			AmountCents:   e.AmountCents,
			SpentOn:       fmtDate(e.SpentOn),
			Description:   e.Description,
			Merchant:      e.Merchant,
			ReceiptURL:    e.ReceiptUrl,
			Status:        e.Status,
			CreatedAt:     e.CreatedAt.Format(time.RFC3339),
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type expenseBody struct {
	ProjectID   *int64 `json:"project_id"`
	Category    string `json:"category"`
	AmountCents int64  `json:"amount_cents"`
	SpentOn     string `json:"spent_on"`
	Description string `json:"description"`
	Merchant    string `json:"merchant"`
	ReceiptURL  string `json:"receipt_url"`
}

func (h *ExpenseHandler) create(w http.ResponseWriter, r *http.Request) {
	var b expenseBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.AmountCents <= 0 {
		writeError(w, http.StatusBadRequest, errors.New("amount is required"))
		return
	}
	spent, err := datePtr(b.SpentOn)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid date"))
		return
	}
	e, err := h.q.CreateExpense(r.Context(), db.CreateExpenseParams{
		UserID:      actorOf(r.Context()),
		ProjectID:   b.ProjectID,
		Category:    validExpenseCategory(b.Category),
		AmountCents: b.AmountCents,
		SpentOn:     spent,
		Description: strings.TrimSpace(b.Description),
		Merchant:    strings.TrimSpace(b.Merchant),
		ReceiptUrl:  strings.TrimSpace(b.ReceiptURL),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, expenseFromRow(e))
}

func (h *ExpenseHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b expenseBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.AmountCents <= 0 {
		writeError(w, http.StatusBadRequest, errors.New("amount is required"))
		return
	}
	spent, err := datePtr(b.SpentOn)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid date"))
		return
	}
	e, err := h.q.UpdateExpense(r.Context(), db.UpdateExpenseParams{
		ID:          id,
		ProjectID:   b.ProjectID,
		Category:    validExpenseCategory(b.Category),
		AmountCents: b.AmountCents,
		SpentOn:     spent,
		Description: strings.TrimSpace(b.Description),
		Merchant:    strings.TrimSpace(b.Merchant),
		ReceiptUrl:  strings.TrimSpace(b.ReceiptURL),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, expenseFromRow(e))
}

type expenseStatusBody struct {
	Status string `json:"status"`
}

func (h *ExpenseHandler) setStatus(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b expenseStatusBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if !validExpenseStatus(b.Status) {
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
		return
	}
	e, err := h.q.SetExpenseStatus(r.Context(), db.SetExpenseStatusParams{
		ID: id, Status: b.Status,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	actor := actorOf(r.Context())
	if e.UserID != nil && (actor == nil || *e.UserID != *actor) {
		notifyUser(r.Context(), h.q, *e.UserID, "expense",
			"Expense "+b.Status,
			actorName(r.Context())+" marked your expense as "+b.Status,
			"/expenses")
	}
	writeJSON(w, http.StatusOK, expenseFromRow(e))
}

func (h *ExpenseHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteExpense(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// expenseFromRow maps a mutation's returned row (no joins) to the API shape;
// the client refreshes the list to pick up submitter and project names.
func expenseFromRow(e db.Expense) expenseResponse {
	return expenseResponse{
		ID:          e.ID,
		UserID:      e.UserID,
		ProjectID:   e.ProjectID,
		Category:    e.Category,
		AmountCents: e.AmountCents,
		SpentOn:     fmtDate(e.SpentOn),
		Description: e.Description,
		Merchant:    e.Merchant,
		ReceiptURL:  e.ReceiptUrl,
		Status:      e.Status,
		CreatedAt:   e.CreatedAt.Format(time.RFC3339),
	}
}
