package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// InvoiceHandler serves /api/v1/invoices — invoices billed from a project's
// unbilled billable time (or built by hand), with a draft → sent → paid
// workflow. Invoiced time entries are flagged so they are never double-billed.
type InvoiceHandler struct {
	q *db.Queries
}

// NewInvoiceHandler wires the handler to the query layer.
func NewInvoiceHandler(q *db.Queries) *InvoiceHandler {
	return &InvoiceHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/invoices.
func (h *InvoiceHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Post("/generate", h.generate)
	r.Get("/{id}", h.get)
	r.Patch("/{id}/status", h.setStatus)
	r.Delete("/{id}", h.delete)
	r.Post("/{id}/lines", h.addLine)
	r.Delete("/{id}/lines/{lineId}", h.deleteLine)
	return r
}

type invoiceResponse struct {
	ID          int64  `json:"id"`
	Number      string `json:"number"`
	ProjectID   *int64 `json:"project_id"`
	ProjectName string `json:"project_name"`
	ClientName  string `json:"client_name"`
	ClientEmail string `json:"client_email"`
	Status      string `json:"status"`
	IssueDate   string `json:"issue_date"`
	DueDate     string `json:"due_date"`
	Notes       string `json:"notes"`
	TotalCents  int64  `json:"total_cents"`
	LineCount   int64  `json:"line_count"`
	CreatedAt   string `json:"created_at"`
}

type invoiceLineResponse struct {
	ID              int64  `json:"id"`
	Description     string `json:"description"`
	QuantityMinutes int32  `json:"quantity_minutes"`
	RateCents       int64  `json:"rate_cents"`
	AmountCents     int64  `json:"amount_cents"`
}

type invoiceDetailResponse struct {
	invoiceResponse
	Lines []invoiceLineResponse `json:"lines"`
}

func validInvoiceStatus(s string) bool {
	switch s {
	case "draft", "sent", "paid", "void":
		return true
	default:
		return false
	}
}

func invoiceFromList(i db.ListInvoicesRow) invoiceResponse {
	return invoiceResponse{
		ID:          i.ID,
		Number:      i.Number,
		ProjectID:   i.ProjectID,
		ProjectName: i.ProjectName,
		ClientName:  i.ClientName,
		ClientEmail: i.ClientEmail,
		Status:      i.Status,
		IssueDate:   fmtDate(i.IssueDate),
		DueDate:     fmtDate(i.DueDate),
		Notes:       i.Notes,
		TotalCents:  i.TotalCents,
		LineCount:   i.LineCount,
		CreatedAt:   i.CreatedAt.Format(time.RFC3339),
	}
}

func (h *InvoiceHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListInvoices(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]invoiceResponse, 0, len(rows))
	for _, i := range rows {
		out = append(out, invoiceFromList(i))
	}
	writeJSON(w, http.StatusOK, out)
}

// writeDetail responds with an invoice plus its line items.
func (h *InvoiceHandler) writeDetail(w http.ResponseWriter, r *http.Request, id int64) {
	inv, err := h.q.GetInvoice(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("not found"))
		return
	}
	lines, err := h.q.ListInvoiceLines(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	outLines := make([]invoiceLineResponse, 0, len(lines))
	for _, l := range lines {
		outLines = append(outLines, invoiceLineResponse{
			ID:              l.ID,
			Description:     l.Description,
			QuantityMinutes: l.QuantityMinutes,
			RateCents:       l.RateCents,
			AmountCents:     l.AmountCents,
		})
	}
	writeJSON(w, http.StatusOK, invoiceDetailResponse{
		invoiceResponse: invoiceResponse{
			ID:          inv.ID,
			Number:      inv.Number,
			ProjectID:   inv.ProjectID,
			ProjectName: inv.ProjectName,
			ClientName:  inv.ClientName,
			ClientEmail: inv.ClientEmail,
			Status:      inv.Status,
			IssueDate:   fmtDate(inv.IssueDate),
			DueDate:     fmtDate(inv.DueDate),
			Notes:       inv.Notes,
			TotalCents:  inv.TotalCents,
			LineCount:   int64(len(lines)),
			CreatedAt:   inv.CreatedAt.Format(time.RFC3339),
		},
		Lines: outLines,
	})
}

func (h *InvoiceHandler) get(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	h.writeDetail(w, r, id)
}

type invoiceBody struct {
	ProjectID   *int64 `json:"project_id"`
	ClientName  string `json:"client_name"`
	ClientEmail string `json:"client_email"`
	IssueDate   string `json:"issue_date"`
	DueDate     string `json:"due_date"`
	Notes       string `json:"notes"`
}

func (h *InvoiceHandler) createInvoice(r *http.Request, b invoiceBody) (db.Invoice, error) {
	issue, err := datePtr(b.IssueDate)
	if err != nil {
		return db.Invoice{}, errors.New("invalid issue date")
	}
	due, err := datePtr(b.DueDate)
	if err != nil {
		return db.Invoice{}, errors.New("invalid due date")
	}
	return h.q.CreateInvoice(r.Context(), db.CreateInvoiceParams{
		ProjectID:   b.ProjectID,
		ClientName:  strings.TrimSpace(b.ClientName),
		ClientEmail: strings.TrimSpace(b.ClientEmail),
		IssueDate:   issue,
		DueDate:     due,
		Notes:       strings.TrimSpace(b.Notes),
	})
}

func (h *InvoiceHandler) create(w http.ResponseWriter, r *http.Request) {
	var b invoiceBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	inv, err := h.createInvoice(r, b)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	h.writeDetail(w, r, inv.ID)
}

type generateBody struct {
	invoiceBody
	RateCents int64 `json:"rate_cents"`
}

func (h *InvoiceHandler) generate(w http.ResponseWriter, r *http.Request) {
	var b generateBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.ProjectID == nil {
		writeError(w, http.StatusBadRequest, errors.New("a project is required"))
		return
	}
	rate := b.RateCents
	if rate <= 0 {
		if pr, err := h.q.GetProjectRate(r.Context(), *b.ProjectID); err == nil {
			rate = pr
		}
	}
	inv, err := h.createInvoice(r, b.invoiceBody)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	groups, err := h.q.UnbilledTimeByUser(r.Context(), b.ProjectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	for idx, g := range groups {
		desc := "Billable time"
		if g.UserName != "" {
			desc = g.UserName + " — billable time"
		}
		if _, err := h.q.AddInvoiceLine(r.Context(), db.AddInvoiceLineParams{
			InvoiceID:       inv.ID,
			Description:     desc,
			QuantityMinutes: int32(g.Minutes),
			RateCents:       rate,
			AmountCents:     g.Minutes * rate / 60,
			Sort:            int32(idx),
		}); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}
	invoiceID := inv.ID
	if err := h.q.MarkProjectTimeInvoiced(r.Context(),
		db.MarkProjectTimeInvoicedParams{
			InvoiceID: &invoiceID,
			ProjectID: b.ProjectID,
		}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.writeDetail(w, r, inv.ID)
}

func (h *InvoiceHandler) setStatus(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if !validInvoiceStatus(b.Status) {
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
		return
	}
	if _, err := h.q.SetInvoiceStatus(r.Context(), db.SetInvoiceStatusParams{
		ID: id, Status: b.Status,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	// Voiding an invoice frees its time entries to be billed again.
	if b.Status == "void" {
		invoiceID := id
		if err := h.q.ReleaseInvoiceTime(r.Context(), &invoiceID); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}
	h.writeDetail(w, r, id)
}

func (h *InvoiceHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	// The time_entries FK is ON DELETE SET NULL, so removing the invoice
	// releases its time automatically.
	if err := h.q.DeleteInvoice(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type addLineBody struct {
	Description     string `json:"description"`
	QuantityMinutes int32  `json:"quantity_minutes"`
	RateCents       int64  `json:"rate_cents"`
	AmountCents     int64  `json:"amount_cents"`
}

func (h *InvoiceHandler) addLine(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b addLineBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	amount := b.AmountCents
	if amount == 0 && b.QuantityMinutes > 0 && b.RateCents > 0 {
		amount = int64(b.QuantityMinutes) * b.RateCents / 60
	}
	if _, err := h.q.AddInvoiceLine(r.Context(), db.AddInvoiceLineParams{
		InvoiceID:       id,
		Description:     strings.TrimSpace(b.Description),
		QuantityMinutes: b.QuantityMinutes,
		RateCents:       b.RateCents,
		AmountCents:     amount,
		Sort:            0,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.writeDetail(w, r, id)
}

func (h *InvoiceHandler) deleteLine(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	lineID, err := strconv.ParseInt(chi.URLParam(r, "lineId"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid line id"))
		return
	}
	if err := h.q.DeleteInvoiceLine(r.Context(), lineID); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	h.writeDetail(w, r, id)
}
