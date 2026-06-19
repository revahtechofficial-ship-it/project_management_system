package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// ObjectiveHandler serves /api/v1/objectives — Goals & OKRs: objectives with
// measurable key results, owners and alignment (a parent objective).
type ObjectiveHandler struct {
	q *db.Queries
}

// NewObjectiveHandler wires the handler to the query layer.
func NewObjectiveHandler(q *db.Queries) *ObjectiveHandler {
	return &ObjectiveHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/objectives.
func (h *ObjectiveHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	r.Post("/{id}/key-results", h.addKeyResult)
	r.Patch("/key-results/{krId}", h.updateKeyResult)
	r.Delete("/key-results/{krId}", h.deleteKeyResult)
	return r
}

type keyResultResponse struct {
	ID           int64   `json:"id"`
	ObjectiveID  int64   `json:"objective_id"`
	Title        string  `json:"title"`
	StartValue   float64 `json:"start_value"`
	CurrentValue float64 `json:"current_value"`
	TargetValue  float64 `json:"target_value"`
	Unit         string  `json:"unit"`
	Progress     float64 `json:"progress"`
}

type objectiveResponse struct {
	ID          int64               `json:"id"`
	Title       string              `json:"title"`
	Description string              `json:"description"`
	OwnerID     *int64              `json:"owner_id"`
	OwnerName   string              `json:"owner_name"`
	ParentID    *int64              `json:"parent_id"`
	Period      string              `json:"period"`
	Status      string              `json:"status"`
	Progress    float64             `json:"progress"`
	KeyResults  []keyResultResponse `json:"key_results"`
	CanManage   bool                `json:"can_manage"`
	CreatedAt   time.Time           `json:"created_at"`
	UpdatedAt   time.Time           `json:"updated_at"`
}

func krProgress(start, current, target float64) float64 {
	if target == start {
		if current >= target {
			return 1
		}
		return 0
	}
	p := (current - start) / (target - start)
	if p < 0 {
		return 0
	}
	if p > 1 {
		return 1
	}
	return p
}

func (h *ObjectiveHandler) list(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	objs, err := h.q.ListObjectives(ctx)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	krs, err := h.q.ListAllKeyResults(ctx)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	byObjective := make(map[int64][]keyResultResponse)
	for _, k := range krs {
		byObjective[k.ObjectiveID] = append(byObjective[k.ObjectiveID], keyResultResponse{
			ID:           k.ID,
			ObjectiveID:  k.ObjectiveID,
			Title:        k.Title,
			StartValue:   k.StartValue,
			CurrentValue: k.CurrentValue,
			TargetValue:  k.TargetValue,
			Unit:         k.Unit,
			Progress:     krProgress(k.StartValue, k.CurrentValue, k.TargetValue),
		})
	}

	actor := actorOf(ctx)
	admin := isAdmin(ctx)
	out := make([]objectiveResponse, 0, len(objs))
	for _, o := range objs {
		list := byObjective[o.ID]
		var sum float64
		for _, k := range list {
			sum += k.Progress
		}
		progress := 0.0
		if len(list) > 0 {
			progress = sum / float64(len(list))
		}
		owns := actor != nil && o.CreatedBy != nil && *o.CreatedBy == *actor
		out = append(out, objectiveResponse{
			ID:          o.ID,
			Title:       o.Title,
			Description: o.Description,
			OwnerID:     o.OwnerID,
			OwnerName:   o.OwnerName,
			ParentID:    o.ParentID,
			Period:      o.Period,
			Status:      o.Status,
			Progress:    progress,
			KeyResults:  list,
			CanManage:   admin || owns,
			CreatedAt:   o.CreatedAt,
			UpdatedAt:   o.UpdatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type objectiveBody struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	OwnerID     *int64 `json:"owner_id"`
	ParentID    *int64 `json:"parent_id"`
	Period      string `json:"period"`
	Status      string `json:"status"`
}

func normObjectiveStatus(s string) string {
	switch s {
	case "active", "completed", "archived":
		return s
	default:
		return "active"
	}
}

func (h *ObjectiveHandler) create(w http.ResponseWriter, r *http.Request) {
	var b objectiveBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Title) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a title is required"))
		return
	}
	if _, err := h.q.CreateObjective(r.Context(), db.CreateObjectiveParams{
		Title:       strings.TrimSpace(b.Title),
		Description: strings.TrimSpace(b.Description),
		OwnerID:     b.OwnerID,
		ParentID:    b.ParentID,
		Period:      strings.TrimSpace(b.Period),
		Status:      normObjectiveStatus(b.Status),
		CreatedBy:   actorOf(r.Context()),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *ObjectiveHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b objectiveBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	// Guard against making an objective its own parent.
	if b.ParentID != nil && *b.ParentID == id {
		b.ParentID = nil
	}
	if err := h.q.UpdateObjective(r.Context(), db.UpdateObjectiveParams{
		ID:          id,
		Title:       strings.TrimSpace(b.Title),
		Description: strings.TrimSpace(b.Description),
		OwnerID:     b.OwnerID,
		ParentID:    b.ParentID,
		Period:      strings.TrimSpace(b.Period),
		Status:      normObjectiveStatus(b.Status),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ObjectiveHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	o, err := h.q.GetObjective(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	actor := actorOf(r.Context())
	owns := actor != nil && o.CreatedBy != nil && *o.CreatedBy == *actor
	if !owns && !isAdmin(r.Context()) {
		writeError(w, http.StatusForbidden, errors.New("only the creator or an admin can delete this objective"))
		return
	}
	if err := h.q.DeleteObjective(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type keyResultBody struct {
	Title        string  `json:"title"`
	StartValue   float64 `json:"start_value"`
	CurrentValue float64 `json:"current_value"`
	TargetValue  float64 `json:"target_value"`
	Unit         string  `json:"unit"`
}

func (h *ObjectiveHandler) addKeyResult(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b keyResultBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if _, err := h.q.CreateKeyResult(r.Context(), db.CreateKeyResultParams{
		ObjectiveID:  id,
		Title:        strings.TrimSpace(b.Title),
		StartValue:   b.StartValue,
		CurrentValue: b.CurrentValue,
		TargetValue:  b.TargetValue,
		Unit:         strings.TrimSpace(b.Unit),
		Position:     0,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *ObjectiveHandler) krParam(r *http.Request) (int64, error) {
	return strconv.ParseInt(chi.URLParam(r, "krId"), 10, 64)
}

func (h *ObjectiveHandler) updateKeyResult(w http.ResponseWriter, r *http.Request) {
	krID, err := h.krParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b keyResultBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.q.UpdateKeyResult(r.Context(), db.UpdateKeyResultParams{
		ID:           krID,
		Title:        strings.TrimSpace(b.Title),
		StartValue:   b.StartValue,
		CurrentValue: b.CurrentValue,
		TargetValue:  b.TargetValue,
		Unit:         strings.TrimSpace(b.Unit),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ObjectiveHandler) deleteKeyResult(w http.ResponseWriter, r *http.Request) {
	krID, err := h.krParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteKeyResult(r.Context(), krID); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
