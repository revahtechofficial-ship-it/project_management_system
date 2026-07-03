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

// AssetHandler serves /api/v1/assets — the company inventory of hardware,
// software and licenses, who they're assigned to and when they expire.
type AssetHandler struct {
	q *db.Queries
}

// NewAssetHandler wires the handler to the query layer.
func NewAssetHandler(q *db.Queries) *AssetHandler {
	return &AssetHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/assets.
func (h *AssetHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

type assetResponse struct {
	ID           int64  `json:"id"`
	Name         string `json:"name"`
	Kind         string `json:"kind"`
	Status       string `json:"status"`
	Identifier   string `json:"identifier"`
	Vendor       string `json:"vendor"`
	AssigneeID   *int64 `json:"assignee_id"`
	AssigneeName string `json:"assignee_name"`
	CostCents    int64  `json:"cost_cents"`
	PurchasedOn  string `json:"purchased_on"`
	ExpiresOn    string `json:"expires_on"`
	Notes        string `json:"notes"`
	CreatedAt    string `json:"created_at"`
}

func validAssetKind(s string) string {
	switch s {
	case "hardware", "software", "license", "accessory":
		return s
	default:
		return "hardware"
	}
}

func validAssetStatus(s string) string {
	switch s {
	case "available", "in_use", "maintenance", "retired":
		return s
	default:
		return "available"
	}
}

// datePtr turns a "YYYY-MM-DD" string into a nullable date; blank means unset.
func datePtr(s string) (pgtype.Date, error) {
	if strings.TrimSpace(s) == "" {
		return pgtype.Date{}, nil
	}
	t, err := time.Parse(dateLayout, s)
	if err != nil {
		return pgtype.Date{}, err
	}
	return pgtype.Date{Time: t, Valid: true}, nil
}

// fmtDate renders a nullable date back as "YYYY-MM-DD", blank when unset.
func fmtDate(d pgtype.Date) string {
	if !d.Valid {
		return ""
	}
	return d.Time.Format(dateLayout)
}

func (h *AssetHandler) list(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListAssets(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]assetResponse, 0, len(rows))
	for _, a := range rows {
		out = append(out, assetResponse{
			ID:           a.ID,
			Name:         a.Name,
			Kind:         a.Kind,
			Status:       a.Status,
			Identifier:   a.Identifier,
			Vendor:       a.Vendor,
			AssigneeID:   a.AssigneeID,
			AssigneeName: a.AssigneeName,
			CostCents:    a.CostCents,
			PurchasedOn:  fmtDate(a.PurchasedOn),
			ExpiresOn:    fmtDate(a.ExpiresOn),
			Notes:        a.Notes,
			CreatedAt:    a.CreatedAt.Format(time.RFC3339),
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type assetBody struct {
	Name        string `json:"name"`
	Kind        string `json:"kind"`
	Status      string `json:"status"`
	Identifier  string `json:"identifier"`
	Vendor      string `json:"vendor"`
	AssigneeID  *int64 `json:"assignee_id"`
	CostCents   int64  `json:"cost_cents"`
	PurchasedOn string `json:"purchased_on"`
	ExpiresOn   string `json:"expires_on"`
	Notes       string `json:"notes"`
}

func (h *AssetHandler) create(w http.ResponseWriter, r *http.Request) {
	var b assetBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	purchased, err := datePtr(b.PurchasedOn)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid purchase date"))
		return
	}
	expires, err := datePtr(b.ExpiresOn)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid expiry date"))
		return
	}
	a, err := h.q.CreateAsset(r.Context(), db.CreateAssetParams{
		Name:        strings.TrimSpace(b.Name),
		Kind:        validAssetKind(b.Kind),
		Status:      validAssetStatus(b.Status),
		Identifier:  strings.TrimSpace(b.Identifier),
		Vendor:      strings.TrimSpace(b.Vendor),
		AssigneeID:  b.AssigneeID,
		CostCents:   b.CostCents,
		PurchasedOn: purchased,
		ExpiresOn:   expires,
		Notes:       strings.TrimSpace(b.Notes),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, assetFromRow(a))
}

func (h *AssetHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b assetBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	purchased, err := datePtr(b.PurchasedOn)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid purchase date"))
		return
	}
	expires, err := datePtr(b.ExpiresOn)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid expiry date"))
		return
	}
	a, err := h.q.UpdateAsset(r.Context(), db.UpdateAssetParams{
		ID:          id,
		Name:        strings.TrimSpace(b.Name),
		Kind:        validAssetKind(b.Kind),
		Status:      validAssetStatus(b.Status),
		Identifier:  strings.TrimSpace(b.Identifier),
		Vendor:      strings.TrimSpace(b.Vendor),
		AssigneeID:  b.AssigneeID,
		CostCents:   b.CostCents,
		PurchasedOn: purchased,
		ExpiresOn:   expires,
		Notes:       strings.TrimSpace(b.Notes),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, assetFromRow(a))
}

func (h *AssetHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteAsset(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// assetFromRow maps a mutation's returned row (no join) to the API shape. The
// assignee name is left blank; the client refreshes the list afterwards.
func assetFromRow(a db.Asset) assetResponse {
	return assetResponse{
		ID:          a.ID,
		Name:        a.Name,
		Kind:        a.Kind,
		Status:      a.Status,
		Identifier:  a.Identifier,
		Vendor:      a.Vendor,
		AssigneeID:  a.AssigneeID,
		CostCents:   a.CostCents,
		PurchasedOn: fmtDate(a.PurchasedOn),
		ExpiresOn:   fmtDate(a.ExpiresOn),
		Notes:       a.Notes,
		CreatedAt:   a.CreatedAt.Format(time.RFC3339),
	}
}
