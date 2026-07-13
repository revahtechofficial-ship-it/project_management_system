package handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// MuhuratHandler serves /api/v1/muhurats — the saait, the auspicious days for
// a marriage or a bratabandha.
//
// These are data, not arithmetic. Rahu Kaal and the rest are computed in the
// client from the length of the day; a saait comes from a published almanac
// and is typed in.
type MuhuratHandler struct {
	q *db.Queries
}

// NewMuhuratHandler wires the handler to the query layer.
func NewMuhuratHandler(q *db.Queries) *MuhuratHandler {
	return &MuhuratHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/muhurats.
func (h *MuhuratHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Delete("/{id}", h.delete)
	return r
}

// muhuratKinds mirrors the CHECK constraint. Unlike a holiday's category, an
// unknown kind is rejected rather than silently downgraded: a saait typed
// against the wrong ceremony is worse than one that failed to save.
var muhuratKinds = map[string]bool{
	"marriage":      true,
	"bratabandha":   true,
	"griha_pravesh": true,
	"annaprashan":   true,
	"business":      true,
	"other":         true,
}

const timeLayout = "15:04"

type muhuratResponse struct {
	ID     int64  `json:"id"`
	Date   string `json:"date"`
	Kind   string `json:"kind"`
	Start  string `json:"start_time"`
	End    string `json:"end_time"`
	NoteEn string `json:"note_en"`
	NoteNe string `json:"note_ne"`
	Source string `json:"source"`
}

// fmtTime renders a pgtype.Time as HH:MM, or "" when the whole day is good.
func fmtTime(t pgtype.Time) string {
	if !t.Valid {
		return ""
	}
	total := t.Microseconds / 1_000_000
	return fmt.Sprintf("%02d:%02d", total/3600, (total%3600)/60)
}

// timePtr parses HH:MM into a pgtype.Time. An empty string is not an error —
// it means the saait covers the whole day.
func timePtr(s string) (pgtype.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return pgtype.Time{}, nil
	}
	t, err := time.Parse(timeLayout, s)
	if err != nil {
		return pgtype.Time{}, err
	}
	micros := int64(t.Hour())*3600_000_000 +
		int64(t.Minute())*60_000_000
	return pgtype.Time{Microseconds: micros, Valid: true}, nil
}

func muhuratFrom(m db.Muhurat) muhuratResponse {
	return muhuratResponse{
		ID:     m.ID,
		Date:   fmtDate(m.MuhuratDate),
		Kind:   m.Kind,
		Start:  fmtTime(m.StartTime),
		End:    fmtTime(m.EndTime),
		NoteEn: m.NoteEn,
		NoteNe: m.NoteNe,
		Source: m.Source,
	}
}

// list returns the saait between `from` and `to`, defaulting to a wide window.
func (h *MuhuratHandler) list(w http.ResponseWriter, r *http.Request) {
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
	rows, err := h.q.ListMuhurats(r.Context(), db.ListMuhuratsParams{
		FromDate: from,
		ToDate:   to,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]muhuratResponse, 0, len(rows))
	for _, m := range rows {
		out = append(out, muhuratFrom(m))
	}
	writeJSON(w, http.StatusOK, out)
}

type muhuratBody struct {
	Date   string `json:"date"`
	Kind   string `json:"kind"`
	Start  string `json:"start_time"`
	End    string `json:"end_time"`
	NoteEn string `json:"note_en"`
	NoteNe string `json:"note_ne"`
	Source string `json:"source"`
}

func (h *MuhuratHandler) create(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b muhuratBody
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
	kind := strings.TrimSpace(strings.ToLower(b.Kind))
	if !muhuratKinds[kind] {
		writeError(w, http.StatusBadRequest,
			fmt.Errorf("unknown kind %q", b.Kind))
		return
	}
	start, err := timePtr(b.Start)
	if err != nil {
		writeError(w, http.StatusBadRequest,
			errors.New("start_time must be HH:MM"))
		return
	}
	end, err := timePtr(b.End)
	if err != nil {
		writeError(w, http.StatusBadRequest,
			errors.New("end_time must be HH:MM"))
		return
	}
	// The table enforces this too, but a clear message beats a constraint
	// violation surfacing as a 500.
	if start.Valid != end.Valid {
		writeError(w, http.StatusBadRequest,
			errors.New("give both a start and an end time, or neither"))
		return
	}
	if start.Valid && end.Microseconds <= start.Microseconds {
		writeError(w, http.StatusBadRequest,
			errors.New("the saait must end after it starts"))
		return
	}

	m, err := h.q.CreateMuhurat(r.Context(), db.CreateMuhuratParams{
		MuhuratDate: date,
		Kind:        kind,
		StartTime:   start,
		EndTime:     end,
		NoteEn:      strings.TrimSpace(b.NoteEn),
		NoteNe:      strings.TrimSpace(b.NoteNe),
		Source:      strings.TrimSpace(b.Source),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, muhuratFrom(m))
}

func (h *MuhuratHandler) delete(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteMuhurat(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
