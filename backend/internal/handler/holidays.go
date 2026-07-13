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
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

// holidayCategories mirrors the CHECK constraint on holidays.category. An
// unrecognised value degrades to "other" rather than failing the write, so an
// older client cannot break holiday creation with a category it invented.
var holidayCategories = map[string]bool{
	"religious":     true,
	"national":      true,
	"local":         true,
	"international": true,
	"other":         true,
}

func validCategory(s string) string {
	s = strings.TrimSpace(strings.ToLower(s))
	if holidayCategories[s] {
		return s
	}
	return "other"
}

type holidayResponse struct {
	ID            int64  `json:"id"`
	Date          string `json:"date"`
	NameEn        string `json:"name_en"`
	NameNe        string `json:"name_ne"`
	IsPublic      bool   `json:"is_public"`
	Category      string `json:"category"`
	DescriptionEn string `json:"description_en"`
	DescriptionNe string `json:"description_ne"`
	HistoryEn     string `json:"history_en"`
	HistoryNe     string `json:"history_ne"`
	ImportanceEn  string `json:"importance_en"`
	ImportanceNe  string `json:"importance_ne"`
	CelebrationEn string `json:"celebration_en"`
	CelebrationNe string `json:"celebration_ne"`
	Aliases       string `json:"aliases"`
}

func holidayFrom(hd db.Holiday) holidayResponse {
	return holidayResponse{
		ID:            hd.ID,
		Date:          fmtDate(hd.HolidayDate),
		NameEn:        hd.NameEn,
		NameNe:        hd.NameNe,
		IsPublic:      hd.IsPublic,
		Category:      hd.Category,
		DescriptionEn: hd.DescriptionEn,
		DescriptionNe: hd.DescriptionNe,
		HistoryEn:     hd.HistoryEn,
		HistoryNe:     hd.HistoryNe,
		ImportanceEn:  hd.ImportanceEn,
		ImportanceNe:  hd.ImportanceNe,
		CelebrationEn: hd.CelebrationEn,
		CelebrationNe: hd.CelebrationNe,
		Aliases:       hd.Aliases,
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
	Date          string `json:"date"`
	NameEn        string `json:"name_en"`
	NameNe        string `json:"name_ne"`
	IsPublic      *bool  `json:"is_public"`
	Category      string `json:"category"`
	DescriptionEn string `json:"description_en"`
	DescriptionNe string `json:"description_ne"`
	HistoryEn     string `json:"history_en"`
	HistoryNe     string `json:"history_ne"`
	ImportanceEn  string `json:"importance_en"`
	ImportanceNe  string `json:"importance_ne"`
	CelebrationEn string `json:"celebration_en"`
	CelebrationNe string `json:"celebration_ne"`
	Aliases       string `json:"aliases"`
}

// decodeHoliday reads the body shared by create and update, and normalises it.
func decodeHoliday(r *http.Request) (holidayBody, error) {
	var b holidayBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		return b, err
	}
	b.NameEn = strings.TrimSpace(b.NameEn)
	if b.NameEn == "" {
		return b, errors.New("a name is required")
	}
	b.NameNe = strings.TrimSpace(b.NameNe)
	b.Category = validCategory(b.Category)
	return b, nil
}

func (b holidayBody) public() bool {
	if b.IsPublic != nil {
		return *b.IsPublic
	}
	return true
}

func (h *HolidayHandler) create(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	b, err := decodeHoliday(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	date, err := datePtr(b.Date)
	if err != nil || !date.Valid {
		writeError(w, http.StatusBadRequest,
			errors.New("a date (YYYY-MM-DD) is required"))
		return
	}
	hd, err := h.q.CreateHoliday(r.Context(), db.CreateHolidayParams{
		HolidayDate:   date,
		NameEn:        b.NameEn,
		NameNe:        b.NameNe,
		IsPublic:      b.public(),
		Category:      b.Category,
		DescriptionEn: b.DescriptionEn,
		DescriptionNe: b.DescriptionNe,
		HistoryEn:     b.HistoryEn,
		HistoryNe:     b.HistoryNe,
		ImportanceEn:  b.ImportanceEn,
		ImportanceNe:  b.ImportanceNe,
		CelebrationEn: b.CelebrationEn,
		CelebrationNe: b.CelebrationNe,
		Aliases:       b.Aliases,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, holidayFrom(hd))
}

func (h *HolidayHandler) update(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	b, err := decodeHoliday(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	date, err := datePtr(b.Date)
	if err != nil || !date.Valid {
		writeError(w, http.StatusBadRequest,
			errors.New("a date (YYYY-MM-DD) is required"))
		return
	}
	hd, err := h.q.UpdateHoliday(r.Context(), db.UpdateHolidayParams{
		ID:            id,
		HolidayDate:   date,
		NameEn:        b.NameEn,
		NameNe:        b.NameNe,
		IsPublic:      b.public(),
		Category:      b.Category,
		DescriptionEn: b.DescriptionEn,
		DescriptionNe: b.DescriptionNe,
		HistoryEn:     b.HistoryEn,
		HistoryNe:     b.HistoryNe,
		ImportanceEn:  b.ImportanceEn,
		ImportanceNe:  b.ImportanceNe,
		CelebrationEn: b.CelebrationEn,
		CelebrationNe: b.CelebrationNe,
		Aliases:       b.Aliases,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, holidayFrom(hd))
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
