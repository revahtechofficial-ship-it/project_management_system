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

// ClientHandler serves /api/v1/clients — external clients and the projects
// assigned to them. Each client has a portal token that unlocks a public,
// read-only view of their projects and invoices (mounted separately).
type ClientHandler struct {
	q *db.Queries
}

// NewClientHandler wires the handler to the query layer.
func NewClientHandler(q *db.Queries) *ClientHandler {
	return &ClientHandler{q: q}
}

// Routes builds the authed sub-router mounted at /api/v1/clients.
func (h *ClientHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	r.Get("/{id}/projects", h.listProjects)
	r.Put("/{id}/projects", h.setProjects)
	return r
}

type clientResponse struct {
	ID           int64  `json:"id"`
	Name         string `json:"name"`
	Company      string `json:"company"`
	Email        string `json:"email"`
	PortalToken  string `json:"portal_token"`
	ProjectCount int64  `json:"project_count"`
	CreatedAt    string `json:"created_at"`
}

func (h *ClientHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListClients(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]clientResponse, 0, len(rows))
	for _, c := range rows {
		out = append(out, clientResponse{
			ID:           c.ID,
			Name:         c.Name,
			Company:      c.Company,
			Email:        c.Email,
			PortalToken:  c.PortalToken,
			ProjectCount: c.ProjectCount,
			CreatedAt:    c.CreatedAt.Format(time.RFC3339),
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type clientBody struct {
	Name    string `json:"name"`
	Company string `json:"company"`
	Email   string `json:"email"`
}

func (h *ClientHandler) create(w http.ResponseWriter, r *http.Request) {
	var b clientBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" && strings.TrimSpace(b.Company) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	c, err := h.q.CreateClient(r.Context(), db.CreateClientParams{
		Name:        strings.TrimSpace(b.Name),
		Company:     strings.TrimSpace(b.Company),
		Email:       strings.TrimSpace(b.Email),
		PortalToken: shareToken(),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, clientResponse{
		ID:          c.ID,
		Name:        c.Name,
		Company:     c.Company,
		Email:       c.Email,
		PortalToken: c.PortalToken,
		CreatedAt:   c.CreatedAt.Format(time.RFC3339),
	})
}

func (h *ClientHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b clientBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	c, err := h.q.UpdateClient(r.Context(), db.UpdateClientParams{
		ID:      id,
		Name:    strings.TrimSpace(b.Name),
		Company: strings.TrimSpace(b.Company),
		Email:   strings.TrimSpace(b.Email),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, clientResponse{
		ID:          c.ID,
		Name:        c.Name,
		Company:     c.Company,
		Email:       c.Email,
		PortalToken: c.PortalToken,
		CreatedAt:   c.CreatedAt.Format(time.RFC3339),
	})
}

func (h *ClientHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteClient(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type clientProjectFlag struct {
	ID       int64  `json:"id"`
	Name     string `json:"name"`
	Assigned bool   `json:"assigned"`
}

func (h *ClientHandler) listProjects(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	rows, err := h.q.ListProjectsWithClientFlag(r.Context(), &id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]clientProjectFlag, 0, len(rows))
	for _, p := range rows {
		out = append(out, clientProjectFlag{
			ID: p.ID, Name: p.Name, Assigned: p.Assigned,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ClientHandler) setProjects(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b struct {
		ProjectIDs []int64 `json:"project_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	// Reset this client's projects, then assign the selected set.
	if err := h.q.ClearClientProjects(r.Context(), &id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	for _, pid := range b.ProjectIDs {
		if err := h.q.SetProjectClient(r.Context(), db.SetProjectClientParams{
			ClientID: &id, ID: pid,
		}); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Public portal ---

type portalProject struct {
	ID          int64      `json:"id"`
	Name        string     `json:"name"`
	Description string     `json:"description"`
	Status      string     `json:"status"`
	DueDate     *time.Time `json:"due_date"`
	TotalTasks  int32      `json:"total_tasks"`
	DoneTasks   int32      `json:"done_tasks"`
}

type portalInvoice struct {
	ID         int64  `json:"id"`
	Number     string `json:"number"`
	Status     string `json:"status"`
	IssueDate  string `json:"issue_date"`
	DueDate    string `json:"due_date"`
	TotalCents int64  `json:"total_cents"`
	CreatedAt  string `json:"created_at"`
}

type portalResponse struct {
	ClientName       string          `json:"client_name"`
	ClientCompany    string          `json:"client_company"`
	ClientEmail      string          `json:"client_email"`
	Projects         []portalProject `json:"projects"`
	Invoices         []portalInvoice `json:"invoices"`
	OutstandingCents int64           `json:"outstanding_cents"`
}

// Portal returns a client's projects and invoices for a valid portal token. It
// is mounted publicly (no auth) — the unguessable token is the credential.
func (h *ClientHandler) Portal(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	c, err := h.q.GetClientByToken(r.Context(), token)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("portal not found"))
		return
	}
	clientID := c.ID
	projects, err := h.q.ListClientProjects(r.Context(), &clientID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	invoices, err := h.q.ListClientInvoices(r.Context(), &clientID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	outProjects := make([]portalProject, 0, len(projects))
	for _, p := range projects {
		outProjects = append(outProjects, portalProject{
			ID:          p.ID,
			Name:        p.Name,
			Description: p.Description,
			Status:      p.Status,
			DueDate:     tsPtr(p.DueDate),
			TotalTasks:  p.TotalTasks,
			DoneTasks:   p.DoneTasks,
		})
	}
	var outstanding int64
	outInvoices := make([]portalInvoice, 0, len(invoices))
	for _, iv := range invoices {
		if iv.Status == "sent" {
			outstanding += iv.TotalCents
		}
		outInvoices = append(outInvoices, portalInvoice{
			ID:         iv.ID,
			Number:     iv.Number,
			Status:     iv.Status,
			IssueDate:  fmtDate(iv.IssueDate),
			DueDate:    fmtDate(iv.DueDate),
			TotalCents: iv.TotalCents,
			CreatedAt:  iv.CreatedAt.Format(time.RFC3339),
		})
	}
	writeJSON(w, http.StatusOK, portalResponse{
		ClientName:       c.Name,
		ClientCompany:    c.Company,
		ClientEmail:      c.Email,
		Projects:         outProjects,
		Invoices:         outInvoices,
		OutstandingCents: outstanding,
	})
}
