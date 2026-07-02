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

// OneOnOneHandler serves /api/v1/one-on-ones — recurring 1:1 meetings between a
// manager and a report, with shared agenda items, notes and action items.
type OneOnOneHandler struct {
	q *db.Queries
}

// NewOneOnOneHandler wires the handler to the query layer.
func NewOneOnOneHandler(q *db.Queries) *OneOnOneHandler {
	return &OneOnOneHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/one-on-ones.
func (h *OneOnOneHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{id}", h.get)
	r.Patch("/{id}", h.reschedule)
	r.Delete("/{id}", h.delete)
	r.Post("/{id}/items", h.addItem)
	r.Patch("/items/{itemId}", h.updateItem)
	r.Delete("/items/{itemId}", h.deleteItem)
	return r
}

type oneOnOneResponse struct {
	ID          int64     `json:"id"`
	ManagerID   int64     `json:"manager_id"`
	ManagerName string    `json:"manager_name"`
	ReportID    int64     `json:"report_id"`
	ReportName  string    `json:"report_name"`
	ScheduledAt time.Time `json:"scheduled_at"`
	CreatedAt   time.Time `json:"created_at"`
}

type oneOnOneItemResponse struct {
	ID         int64     `json:"id"`
	MeetingID  int64     `json:"meeting_id"`
	AuthorName string    `json:"author_name"`
	Kind       string    `json:"kind"`
	Body       string    `json:"body"`
	Done       bool      `json:"done"`
	CreatedAt  time.Time `json:"created_at"`
}

type oneOnOneDetail struct {
	oneOnOneResponse
	Items []oneOnOneItemResponse `json:"items"`
}

func meetingFromGet(m db.GetOneOnOneRow) oneOnOneResponse {
	return oneOnOneResponse{
		ID:          m.ID,
		ManagerID:   m.ManagerID,
		ManagerName: m.ManagerName,
		ReportID:    m.ReportID,
		ReportName:  m.ReportName,
		ScheduledAt: m.ScheduledAt,
		CreatedAt:   m.CreatedAt,
	}
}

// access loads a meeting and confirms the current user is a participant.
func (h *OneOnOneHandler) access(w http.ResponseWriter, r *http.Request,
	meetingID int64) (db.GetOneOnOneRow, bool) {
	m, err := h.q.GetOneOnOne(r.Context(), meetingID)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("not found"))
		return db.GetOneOnOneRow{}, false
	}
	actor := actorOf(r.Context())
	if actor == nil || (*actor != m.ManagerID && *actor != m.ReportID) {
		writeError(w, http.StatusForbidden, errors.New("forbidden"))
		return db.GetOneOnOneRow{}, false
	}
	return m, true
}

func (h *OneOnOneHandler) list(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	rows, err := h.q.ListMyOneOnOnes(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]oneOnOneResponse, 0, len(rows))
	for _, m := range rows {
		out = append(out, oneOnOneResponse{
			ID:          m.ID,
			ManagerID:   m.ManagerID,
			ManagerName: m.ManagerName,
			ReportID:    m.ReportID,
			ReportName:  m.ReportName,
			ScheduledAt: m.ScheduledAt,
			CreatedAt:   m.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type createOneOnOneBody struct {
	ReportID    int64  `json:"report_id"`
	ScheduledAt string `json:"scheduled_at"`
}

func (h *OneOnOneHandler) create(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("no actor"))
		return
	}
	var b createOneOnOneBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.ReportID == 0 || b.ReportID == *actor {
		writeError(w, http.StatusBadRequest, errors.New("invalid report"))
		return
	}
	when, ok := parseDay(b.ScheduledAt)
	if !ok {
		writeError(w, http.StatusBadRequest, errors.New("invalid scheduled_at"))
		return
	}
	created, err := h.q.CreateOneOnOne(r.Context(), db.CreateOneOnOneParams{
		ManagerID:   *actor,
		ReportID:    b.ReportID,
		ScheduledAt: when,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	notifyUser(r.Context(), h.q, b.ReportID, "one_on_one",
		"1:1 scheduled",
		"A 1:1 was scheduled for "+when.Format("Jan 2, 3:04 PM")+".",
		"/one-on-ones")
	m, err := h.q.GetOneOnOne(r.Context(), created.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, meetingFromGet(m))
}

func (h *OneOnOneHandler) get(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	m, ok := h.access(w, r, id)
	if !ok {
		return
	}
	items, err := h.q.ListOneOnOneItems(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	list := make([]oneOnOneItemResponse, 0, len(items))
	for _, i := range items {
		list = append(list, oneOnOneItemResponse{
			ID:         i.ID,
			MeetingID:  i.MeetingID,
			AuthorName: i.AuthorName,
			Kind:       i.Kind,
			Body:       i.Body,
			Done:       i.Done,
			CreatedAt:  i.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, oneOnOneDetail{
		oneOnOneResponse: meetingFromGet(m),
		Items:            list,
	})
}

type rescheduleBody struct {
	ScheduledAt string `json:"scheduled_at"`
}

func (h *OneOnOneHandler) reschedule(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if _, ok := h.access(w, r, id); !ok {
		return
	}
	var b rescheduleBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	when, ok := parseDay(b.ScheduledAt)
	if !ok {
		writeError(w, http.StatusBadRequest, errors.New("invalid scheduled_at"))
		return
	}
	if err := h.q.RescheduleOneOnOne(r.Context(), db.RescheduleOneOnOneParams{
		ID: id, ScheduledAt: when,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *OneOnOneHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	m, ok := h.access(w, r, id)
	if !ok {
		return
	}
	actor := actorOf(r.Context())
	if actor == nil || *actor != m.ManagerID {
		writeError(w, http.StatusForbidden, errors.New("only the manager can delete"))
		return
	}
	if err := h.q.DeleteOneOnOne(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type addItemBody struct {
	Kind string `json:"kind"`
	Body string `json:"body"`
}

func (h *OneOnOneHandler) addItem(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if _, ok := h.access(w, r, id); !ok {
		return
	}
	var b addItemBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	kind := b.Kind
	if kind != "agenda" && kind != "note" && kind != "action" {
		kind = "agenda"
	}
	if strings.TrimSpace(b.Body) == "" {
		writeError(w, http.StatusBadRequest, errors.New("body is required"))
		return
	}
	item, err := h.q.AddOneOnOneItem(r.Context(), db.AddOneOnOneItemParams{
		MeetingID: id,
		AuthorID:  actorOf(r.Context()),
		Kind:      kind,
		Body:      strings.TrimSpace(b.Body),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, oneOnOneItemResponse{
		ID:        item.ID,
		MeetingID: item.MeetingID,
		Kind:      item.Kind,
		Body:      item.Body,
		Done:      item.Done,
		CreatedAt: item.CreatedAt,
	})
}

func (h *OneOnOneHandler) itemID(r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(chi.URLParam(r, "itemId"), 10, 64)
	if err != nil {
		return 0, false
	}
	return id, true
}

// itemAccess confirms the current user participates in the item's meeting.
func (h *OneOnOneHandler) itemAccess(w http.ResponseWriter, r *http.Request,
	itemID int64) bool {
	meetingID, err := h.q.GetOneOnOneItemMeeting(r.Context(), itemID)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("not found"))
		return false
	}
	_, ok := h.access(w, r, meetingID)
	return ok
}

type updateItemBody struct {
	Done *bool   `json:"done"`
	Body *string `json:"body"`
}

func (h *OneOnOneHandler) updateItem(w http.ResponseWriter, r *http.Request) {
	itemID, ok := h.itemID(r)
	if !ok {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if !h.itemAccess(w, r, itemID) {
		return
	}
	var b updateItemBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Done != nil {
		if err := h.q.SetOneOnOneItemDone(r.Context(),
			db.SetOneOnOneItemDoneParams{ID: itemID, Done: *b.Done}); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}
	if b.Body != nil {
		if err := h.q.UpdateOneOnOneItem(r.Context(),
			db.UpdateOneOnOneItemParams{
				ID: itemID, Body: strings.TrimSpace(*b.Body),
			}); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *OneOnOneHandler) deleteItem(w http.ResponseWriter, r *http.Request) {
	itemID, ok := h.itemID(r)
	if !ok {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if !h.itemAccess(w, r, itemID) {
		return
	}
	if err := h.q.DeleteOneOnOneItem(r.Context(), itemID); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
