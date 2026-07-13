package handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// DailyHandler serves /api/v1/daily — the parts of a patro that cannot be
// computed: the observances, the quote, the rashifal.
//
// Everything the panchang can work out — tithi, nakshatra, Rahu Kaal, the
// fasts — is computed in the client and never touches this handler. What is
// here is what somebody had to write down.
type DailyHandler struct {
	q *db.Queries
}

// NewDailyHandler wires the handler to the query layer.
func NewDailyHandler(q *db.Queries) *DailyHandler {
	return &DailyHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/daily.
func (h *DailyHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/observances", h.listObservances)
	r.Post("/observances", h.createObservance)
	r.Delete("/observances/{id}", h.deleteObservance)

	r.Get("/quote", h.quoteOfTheDay)
	r.Get("/quotes", h.listQuotes)
	r.Post("/quotes", h.createQuote)
	r.Delete("/quotes/{id}", h.deleteQuote)

	r.Get("/rashifal", h.rashifal)
	r.Post("/rashifal", h.createRashifal)
	r.Delete("/rashifal/{id}", h.deleteRashifal)
	return r
}

// ---- observances -----------------------------------------------------------

type observanceResponse struct {
	ID     int64  `json:"id"`
	Month  int32  `json:"month"`
	Day    int32  `json:"day"`
	NameEn string `json:"name_en"`
	NameNe string `json:"name_ne"`
	Scope  string `json:"scope"`
	NoteEn string `json:"note_en"`
	NoteNe string `json:"note_ne"`
	Source string `json:"source"`
}

func observanceFrom(o db.Observance) observanceResponse {
	return observanceResponse{
		ID:     o.ID,
		Month:  o.Month,
		Day:    o.Day,
		NameEn: o.NameEn,
		NameNe: o.NameNe,
		Scope:  o.Scope,
		NoteEn: o.NoteEn,
		NoteNe: o.NoteNe,
		Source: o.Source,
	}
}

// listObservances returns the lot. There are a few dozen, they recur every
// year, and the client matches them against a date by month and day — so
// there is nothing to paginate and no window to ask for.
func (h *DailyHandler) listObservances(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListObservances(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]observanceResponse, 0, len(rows))
	for _, o := range rows {
		out = append(out, observanceFrom(o))
	}
	writeJSON(w, http.StatusOK, out)
}

var observanceScopes = map[string]bool{
	"international": true,
	"national":      true,
	"awareness":     true,
}

type observanceBody struct {
	Month  int32  `json:"month"`
	Day    int32  `json:"day"`
	NameEn string `json:"name_en"`
	NameNe string `json:"name_ne"`
	Scope  string `json:"scope"`
	NoteEn string `json:"note_en"`
	NoteNe string `json:"note_ne"`
	Source string `json:"source"`
}

func (h *DailyHandler) createObservance(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b observanceBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.NameEn)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a name is required"))
		return
	}
	if b.Month < 1 || b.Month > 12 || b.Day < 1 || b.Day > 31 {
		writeError(w, http.StatusBadRequest,
			errors.New("month must be 1-12 and day 1-31"))
		return
	}
	scope := strings.TrimSpace(strings.ToLower(b.Scope))
	if scope == "" {
		scope = "international"
	}
	if !observanceScopes[scope] {
		writeError(w, http.StatusBadRequest,
			fmt.Errorf("unknown scope %q", b.Scope))
		return
	}
	o, err := h.q.CreateObservance(r.Context(), db.CreateObservanceParams{
		Month:  b.Month,
		Day:    b.Day,
		NameEn: name,
		NameNe: strings.TrimSpace(b.NameNe),
		Scope:  scope,
		NoteEn: strings.TrimSpace(b.NoteEn),
		NoteNe: strings.TrimSpace(b.NoteNe),
		Source: strings.TrimSpace(b.Source),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, observanceFrom(o))
}

func (h *DailyHandler) deleteObservance(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteObservance(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---- quotes ----------------------------------------------------------------

type quoteResponse struct {
	ID     int64  `json:"id"`
	TextEn string `json:"text_en"`
	TextNe string `json:"text_ne"`
	Author string `json:"author"`
	Source string `json:"source"`
}

func quoteFrom(q db.Quote) quoteResponse {
	return quoteResponse{
		ID:     q.ID,
		TextEn: q.TextEn,
		TextNe: q.TextNe,
		Author: q.Author,
		Source: q.Source,
	}
}

// quoteOfTheDay picks by rotating the table on the day of the year.
//
// Deterministic on purpose: the same day always gives the same quote, so it
// does not change under the reader when the page refreshes, and there is no
// scheduled job to forget to run. An empty table returns 204 rather than an
// invented quote.
func (h *DailyHandler) quoteOfTheDay(w http.ResponseWriter, r *http.Request) {
	on := time.Now()
	if raw := r.URL.Query().Get("date"); raw != "" {
		parsed, err := time.Parse(dateLayout, raw)
		if err != nil {
			writeError(w, http.StatusBadRequest,
				errors.New("date must be YYYY-MM-DD"))
			return
		}
		on = parsed
	}
	// Days since the epoch, so the rotation carries across a year boundary
	// instead of restarting on 1 January.
	index := on.Unix() / 86400

	q, err := h.q.QuoteForDay(r.Context(), index)
	if errors.Is(err, pgx.ErrNoRows) {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, quoteFrom(q))
}

func (h *DailyHandler) listQuotes(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListQuotes(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]quoteResponse, 0, len(rows))
	for _, q := range rows {
		out = append(out, quoteFrom(q))
	}
	writeJSON(w, http.StatusOK, out)
}

type quoteBody struct {
	TextEn string `json:"text_en"`
	TextNe string `json:"text_ne"`
	Author string `json:"author"`
	Source string `json:"source"`
}

func (h *DailyHandler) createQuote(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b quoteBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.TextEn) == "" && strings.TrimSpace(b.TextNe) == "" {
		writeError(w, http.StatusBadRequest,
			errors.New("a quote needs some words"))
		return
	}
	q, err := h.q.CreateQuote(r.Context(), db.CreateQuoteParams{
		TextEn: strings.TrimSpace(b.TextEn),
		TextNe: strings.TrimSpace(b.TextNe),
		Author: strings.TrimSpace(b.Author),
		Source: strings.TrimSpace(b.Source),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, quoteFrom(q))
}

func (h *DailyHandler) deleteQuote(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteQuote(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---- rashifal --------------------------------------------------------------

type rashifalResponse struct {
	ID     int64  `json:"id"`
	Rashi  int32  `json:"rashi"`
	Period string `json:"period"`
	From   string `json:"from_date"`
	To     string `json:"to_date"`
	TextEn string `json:"text_en"`
	TextNe string `json:"text_ne"`
	Source string `json:"source"`
}

func rashifalFrom(r db.Rashifal) rashifalResponse {
	return rashifalResponse{
		ID:     r.ID,
		Rashi:  r.Rashi,
		Period: r.Period,
		From:   fmtDate(r.FromDate),
		To:     fmtDate(r.ToDate),
		TextEn: r.TextEn,
		TextNe: r.TextNe,
		Source: r.Source,
	}
}

// rashifal returns every reading covering the given day — daily, weekly and
// monthly, for all twelve signs — in one call.
//
// Empty until an astrologer's readings are entered. There is no algorithm for
// a horoscope and this does not pretend otherwise: it would be the only thing
// on the page that was simply made up.
func (h *DailyHandler) rashifal(w http.ResponseWriter, r *http.Request) {
	on, err := datePtr(r.URL.Query().Get("date"))
	if err != nil {
		writeError(w, http.StatusBadRequest,
			errors.New("date must be YYYY-MM-DD"))
		return
	}
	if !on.Valid {
		on, _ = datePtr(time.Now().Format(dateLayout))
	}
	rows, err := h.q.RashifalForDay(r.Context(), on)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]rashifalResponse, 0, len(rows))
	for _, row := range rows {
		out = append(out, rashifalFrom(row))
	}
	writeJSON(w, http.StatusOK, out)
}

var rashifalPeriods = map[string]bool{
	"daily":   true,
	"weekly":  true,
	"monthly": true,
}

type rashifalBody struct {
	Rashi  int32  `json:"rashi"`
	Period string `json:"period"`
	From   string `json:"from_date"`
	To     string `json:"to_date"`
	TextEn string `json:"text_en"`
	TextNe string `json:"text_ne"`
	Source string `json:"source"`
}

func (h *DailyHandler) createRashifal(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b rashifalBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Rashi < 0 || b.Rashi > 11 {
		writeError(w, http.StatusBadRequest,
			errors.New("rashi must be 0 (Mesh) to 11 (Meen)"))
		return
	}
	period := strings.TrimSpace(strings.ToLower(b.Period))
	if !rashifalPeriods[period] {
		writeError(w, http.StatusBadRequest,
			fmt.Errorf("period must be daily, weekly or monthly, not %q",
				b.Period))
		return
	}
	from, err := datePtr(b.From)
	if err != nil || !from.Valid {
		writeError(w, http.StatusBadRequest,
			errors.New("from_date (YYYY-MM-DD) is required"))
		return
	}
	to, err := datePtr(b.To)
	if err != nil || !to.Valid {
		// A daily reading covers one day, so let the client omit it.
		to = from
	}
	if to.Time.Before(from.Time) {
		writeError(w, http.StatusBadRequest,
			errors.New("to_date cannot be before from_date"))
		return
	}
	if strings.TrimSpace(b.TextEn) == "" && strings.TrimSpace(b.TextNe) == "" {
		writeError(w, http.StatusBadRequest,
			errors.New("a reading needs some words"))
		return
	}

	row, err := h.q.CreateRashifal(r.Context(), db.CreateRashifalParams{
		Rashi:    b.Rashi,
		Period:   period,
		FromDate: from,
		ToDate:   to,
		TextEn:   strings.TrimSpace(b.TextEn),
		TextNe:   strings.TrimSpace(b.TextNe),
		Source:   strings.TrimSpace(b.Source),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, rashifalFrom(row))
}

func (h *DailyHandler) deleteRashifal(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteRashifal(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
