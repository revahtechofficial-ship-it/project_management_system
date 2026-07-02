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

// ApprovalHandler serves /api/v1/approvals — request/approve/reject sign-off on
// a task, page or release. Subjects are referenced polymorphically so the same
// queue works across entity types.
type ApprovalHandler struct {
	q *db.Queries
}

// NewApprovalHandler wires the handler to the query layer.
func NewApprovalHandler(q *db.Queries) *ApprovalHandler {
	return &ApprovalHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/approvals.
func (h *ApprovalHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/pending", h.pending)
	r.Get("/mine", h.mine)
	r.Get("/subject", h.forSubject)
	r.Post("/", h.request)
	r.Post("/{id}/decide", h.decide)
	return r
}

type approvalResponse struct {
	ID            int64      `json:"id"`
	SubjectType   string     `json:"subject_type"`
	SubjectID     int64      `json:"subject_id"`
	SubjectTitle  string     `json:"subject_title"`
	RequesterID   int64      `json:"requester_id"`
	RequesterName string     `json:"requester_name"`
	ApproverID    int64      `json:"approver_id"`
	ApproverName  string     `json:"approver_name"`
	Status        string     `json:"status"`
	Note          string     `json:"note"`
	DecidedAt     *time.Time `json:"decided_at"`
	CreatedAt     time.Time  `json:"created_at"`
}

func validSubjectType(s string) bool {
	switch s {
	case "task", "page", "release":
		return true
	default:
		return false
	}
}

func (h *ApprovalHandler) pending(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	rows, err := h.q.ListPendingApprovals(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]approvalResponse, 0, len(rows))
	for _, a := range rows {
		out = append(out, approvalResponse{
			ID:            a.ID,
			SubjectType:   a.SubjectType,
			SubjectID:     a.SubjectID,
			SubjectTitle:  a.SubjectTitle,
			RequesterID:   a.RequesterID,
			RequesterName: a.RequesterName,
			ApproverID:    a.ApproverID,
			Status:        a.Status,
			Note:          a.Note,
			DecidedAt:     tsPtr(a.DecidedAt),
			CreatedAt:     a.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ApprovalHandler) mine(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	rows, err := h.q.ListMyApprovalRequests(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]approvalResponse, 0, len(rows))
	for _, a := range rows {
		out = append(out, approvalResponse{
			ID:           a.ID,
			SubjectType:  a.SubjectType,
			SubjectID:    a.SubjectID,
			SubjectTitle: a.SubjectTitle,
			RequesterID:  a.RequesterID,
			ApproverID:   a.ApproverID,
			ApproverName: a.ApproverName,
			Status:       a.Status,
			Note:         a.Note,
			DecidedAt:    tsPtr(a.DecidedAt),
			CreatedAt:    a.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ApprovalHandler) forSubject(w http.ResponseWriter, r *http.Request) {
	typ := r.URL.Query().Get("type")
	id, err := strconv.ParseInt(r.URL.Query().Get("id"), 10, 64)
	if err != nil || !validSubjectType(typ) {
		writeError(w, http.StatusBadRequest, errors.New("invalid subject"))
		return
	}
	rows, err := h.q.ListApprovalsForSubject(r.Context(),
		db.ListApprovalsForSubjectParams{SubjectType: typ, SubjectID: id})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]approvalResponse, 0, len(rows))
	for _, a := range rows {
		out = append(out, approvalResponse{
			ID:            a.ID,
			SubjectType:   a.SubjectType,
			SubjectID:     a.SubjectID,
			SubjectTitle:  a.SubjectTitle,
			RequesterID:   a.RequesterID,
			RequesterName: a.RequesterName,
			ApproverID:    a.ApproverID,
			ApproverName:  a.ApproverName,
			Status:        a.Status,
			Note:          a.Note,
			DecidedAt:     tsPtr(a.DecidedAt),
			CreatedAt:     a.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type requestApprovalBody struct {
	SubjectType  string `json:"subject_type"`
	SubjectID    int64  `json:"subject_id"`
	SubjectTitle string `json:"subject_title"`
	ApproverID   int64  `json:"approver_id"`
	Note         string `json:"note"`
}

func (h *ApprovalHandler) request(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	var b requestApprovalBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if !validSubjectType(b.SubjectType) || b.SubjectID == 0 || b.ApproverID == 0 {
		writeError(w, http.StatusBadRequest, errors.New("invalid request"))
		return
	}
	row, err := h.q.CreateApproval(r.Context(), db.CreateApprovalParams{
		SubjectType:  b.SubjectType,
		SubjectID:    b.SubjectID,
		SubjectTitle: strings.TrimSpace(b.SubjectTitle),
		RequesterID:  *actor,
		ApproverID:   b.ApproverID,
		Note:         strings.TrimSpace(b.Note),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	notifyUser(r.Context(), h.q, b.ApproverID, "approval",
		"Approval requested",
		actorName(r.Context())+" asked you to approve: "+row.SubjectTitle,
		"/approvals")
	writeJSON(w, http.StatusCreated, approvalResponse{
		ID:           row.ID,
		SubjectType:  row.SubjectType,
		SubjectID:    row.SubjectID,
		SubjectTitle: row.SubjectTitle,
		RequesterID:  row.RequesterID,
		ApproverID:   row.ApproverID,
		Status:       row.Status,
		Note:         row.Note,
		CreatedAt:    row.CreatedAt,
	})
}

func (h *ApprovalHandler) decide(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	existing, err := h.q.GetApproval(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("not found"))
		return
	}
	if existing.ApproverID != *actor {
		writeError(w, http.StatusForbidden, errors.New("not the approver"))
		return
	}
	var b decideBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Status != "approved" && b.Status != "rejected" {
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
		return
	}
	row, err := h.q.DecideApproval(r.Context(), db.DecideApprovalParams{
		ID: id, Status: b.Status,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	notifyUser(r.Context(), h.q, row.RequesterID, "approval",
		"Approval "+b.Status,
		actorName(r.Context())+" "+b.Status+" your request: "+row.SubjectTitle,
		"/approvals")
	writeJSON(w, http.StatusOK, approvalResponse{
		ID:           row.ID,
		SubjectType:  row.SubjectType,
		SubjectID:    row.SubjectID,
		SubjectTitle: row.SubjectTitle,
		RequesterID:  row.RequesterID,
		ApproverID:   row.ApproverID,
		Status:       row.Status,
		Note:         row.Note,
		DecidedAt:    tsPtr(row.DecidedAt),
		CreatedAt:    row.CreatedAt,
	})
}
