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

// HolidayHandler serves /api/v1/holidays — the calendar's holiday list. Dates
// are stored in the Gregorian (AD) calendar; the client renders them against
// both the AD and Bikram Sambat (BS) calendars.
type HolidayHandler struct {
	q *db.Queries
}

// NewHolidayHandler wires the handler to the query layer.
func NewHolidayHandler(q *db.Queries) *HolidayHandler {
	return &HolidayHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/holidays.
func (h *HolidayHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Delete("/{id}", h.delete)
	return r
}

type holidayResponse struct {
	ID       int64  `json:"id"`
	Date     string `json:"date"`
	NameEn   string `json:"name_en"`
	NameNe   string `json:"name_ne"`
	IsPublic bool   `json:"is_public"`
}

func holidayFrom(hd db.Holiday) holidayResponse {
	return holidayResponse{
		ID:       hd.ID,
		Date:     fmtDate(hd.HolidayDate),
		NameEn:   hd.NameEn,
		NameNe:   hd.NameNe,
		IsPublic: hd.IsPublic,
	}
}

// list returns holidays between the `from` and `to` query dates (YYYY-MM-DD).
// Both default to a wide window around today when omitted.
func (h *HolidayHandler) list(w http.ResponseWriter, r *http.Request) {
	now := time.Now()
	from, err := datePtr(r.URL.Query().Get("from"))
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid from date"))
		return
	}
	if !from.Valid {
		from, _ = datePtr(now.AddDate(-1, 0, 0).Format(dateLayout))
	}
	to, err := datePtr(r.URL.Query().Get("to"))
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid to date"))
		return
	}
	if !to.Valid {
		to, _ = datePtr(now.AddDate(2, 0, 0).Format(dateLayout))
	}
	rows, err := h.q.ListHolidays(r.Context(), db.ListHolidaysParams{
		FromDate: from,
		ToDate:   to,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]holidayResponse, 0, len(rows))
	for _, hd := range rows {
		out = append(out, holidayFrom(hd))
	}
	writeJSON(w, http.StatusOK, out)
}

type holidayBody struct {
	Date     string `json:"date"`
	NameEn   string `json:"name_en"`
	NameNe   string `json:"name_ne"`
	IsPublic *bool  `json:"is_public"`
}

func (h *HolidayHandler) create(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b holidayBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	date, err := datePtr(b.Date)
	if err != nil || !date.Valid {
		writeError(w, http.StatusBadRequest,
			errors.New("a date (YYYY-MM-DD) is required"))
		return
	}
	name := strings.TrimSpace(b.NameEn)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	public := true
	if b.IsPublic != nil {
		public = *b.IsPublic
	}
	hd, err := h.q.CreateHoliday(r.Context(), db.CreateHolidayParams{
		HolidayDate: date,
		NameEn:      name,
		NameNe:      strings.TrimSpace(b.NameNe),
		IsPublic:    public,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, holidayFrom(hd))
}

func (h *HolidayHandler) delete(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteHoliday(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
