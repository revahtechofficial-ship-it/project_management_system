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

// ProductivityHandler serves the personal productivity resources: favorites,
// saved task filters and user reminders.
type ProductivityHandler struct {
	q *db.Queries
}

// NewProductivityHandler wires the handler to the query layer.
func NewProductivityHandler(q *db.Queries) *ProductivityHandler {
	return &ProductivityHandler{q: q}
}

func (h *ProductivityHandler) userID(r *http.Request) (int64, bool) {
	if a := actorOf(r.Context()); a != nil {
		return *a, true
	}
	return 0, false
}

// --- favorites -------------------------------------------------------------

// FavoriteRoutes is mounted at /api/v1/favorites.
func (h *ProductivityHandler) FavoriteRoutes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.listFavorites)
	r.Post("/", h.addFavorite)
	r.Delete("/{kind}/{id}", h.removeFavorite)
	return r
}

type favoriteResponse struct {
	ID     int64  `json:"id"`
	Kind   string `json:"kind"`
	ItemID int64  `json:"item_id"`
	Label  string `json:"label"`
	Route  string `json:"route"`
}

func (h *ProductivityHandler) listFavorites(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	rows, err := h.q.ListFavorites(r.Context(), uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]favoriteResponse, 0, len(rows))
	for _, f := range rows {
		out = append(out, favoriteResponse{
			ID: f.ID, Kind: f.Kind, ItemID: f.ItemID,
			Label: f.Label, Route: f.Route,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ProductivityHandler) addFavorite(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b struct {
		Kind   string `json:"kind"`
		ItemID int64  `json:"item_id"`
		Label  string `json:"label"`
		Route  string `json:"route"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Kind == "" || b.ItemID == 0 {
		writeError(w, http.StatusBadRequest, errors.New("kind and item_id are required"))
		return
	}
	if err := h.q.AddFavorite(r.Context(), db.AddFavoriteParams{
		UserID: uid, Kind: b.Kind, ItemID: b.ItemID,
		Label: b.Label, Route: b.Route,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *ProductivityHandler) removeFavorite(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	itemID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.RemoveFavorite(r.Context(), db.RemoveFavoriteParams{
		UserID: uid, Kind: chi.URLParam(r, "kind"), ItemID: itemID,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- saved filters ---------------------------------------------------------

// FilterRoutes is mounted at /api/v1/saved-filters.
func (h *ProductivityHandler) FilterRoutes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.listFilters)
	r.Post("/", h.createFilter)
	r.Delete("/{id}", h.deleteFilter)
	return r
}

type savedFilterResponse struct {
	ID     int64          `json:"id"`
	Name   string         `json:"name"`
	Config map[string]any `json:"config"`
}

func (h *ProductivityHandler) listFilters(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	rows, err := h.q.ListSavedFilters(r.Context(), uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]savedFilterResponse, 0, len(rows))
	for _, f := range rows {
		cfg := map[string]any{}
		_ = json.Unmarshal([]byte(f.Config), &cfg)
		out = append(out, savedFilterResponse{ID: f.ID, Name: f.Name, Config: cfg})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ProductivityHandler) createFilter(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b struct {
		Name   string         `json:"name"`
		Config map[string]any `json:"config"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	if b.Config == nil {
		b.Config = map[string]any{}
	}
	cfg, _ := json.Marshal(b.Config)
	row, err := h.q.CreateSavedFilter(r.Context(), db.CreateSavedFilterParams{
		UserID: uid, Name: strings.TrimSpace(b.Name), Config: string(cfg),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, savedFilterResponse{
		ID: row.ID, Name: row.Name, Config: b.Config,
	})
}

func (h *ProductivityHandler) deleteFilter(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteSavedFilter(r.Context(), db.DeleteSavedFilterParams{
		ID: id, UserID: uid,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- reminders -------------------------------------------------------------

// ReminderRoutes is mounted at /api/v1/reminders.
func (h *ProductivityHandler) ReminderRoutes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.listReminders)
	r.Post("/", h.createReminder)
	r.Delete("/{id}", h.deleteReminder)
	return r
}

type reminderResponse struct {
	ID        int64     `json:"id"`
	TaskID    *int64    `json:"task_id"`
	TaskTitle string    `json:"task_title"`
	Note      string    `json:"note"`
	RemindAt  time.Time `json:"remind_at"`
	Sent      bool      `json:"sent"`
}

func (h *ProductivityHandler) listReminders(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	rows, err := h.q.ListReminders(r.Context(), uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]reminderResponse, 0, len(rows))
	for _, rm := range rows {
		out = append(out, reminderResponse{
			ID: rm.ID, TaskID: rm.TaskID, TaskTitle: rm.TaskTitle,
			Note: rm.Note, RemindAt: rm.RemindAt, Sent: rm.Sent,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *ProductivityHandler) createReminder(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b struct {
		TaskID   *int64    `json:"task_id"`
		Note     string    `json:"note"`
		RemindAt time.Time `json:"remind_at"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.RemindAt.IsZero() {
		writeError(w, http.StatusBadRequest, errors.New("remind_at is required"))
		return
	}
	row, err := h.q.CreateReminder(r.Context(), db.CreateReminderParams{
		UserID: uid, TaskID: b.TaskID, Note: strings.TrimSpace(b.Note),
		RemindAt: b.RemindAt,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, reminderResponse{
		ID: row.ID, TaskID: row.TaskID, Note: row.Note,
		RemindAt: row.RemindAt, Sent: row.Sent,
	})
}

func (h *ProductivityHandler) deleteReminder(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteReminder(r.Context(), db.DeleteReminderParams{
		ID: id, UserID: uid,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
