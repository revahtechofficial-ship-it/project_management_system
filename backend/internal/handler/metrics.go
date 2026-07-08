package handler

import (
	"math"
	"net/http"
	"sort"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// MetricsHandler serves /api/v1/metrics — delivery analytics derived from task
// completion times (cycle time, lead time, throughput).
type MetricsHandler struct {
	q *db.Queries
}

// NewMetricsHandler wires the handler to the query layer.
func NewMetricsHandler(q *db.Queries) *MetricsHandler {
	return &MetricsHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/metrics.
func (h *MetricsHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/cycle-time", h.cycleTime)
	return r
}

type cyclePoint struct {
	ID          int64     `json:"id"`
	Title       string    `json:"title"`
	CompletedAt time.Time `json:"completed_at"`
	LeadDays    float64   `json:"lead_days"`
	CycleDays   *float64  `json:"cycle_days"`
}

type cycleMetricsResponse struct {
	CompletedCount    int          `json:"completed_count"`
	Days              int          `json:"days"`
	AvgLeadDays       float64      `json:"avg_lead_days"`
	MedianLeadDays    float64      `json:"median_lead_days"`
	P85LeadDays       float64      `json:"p85_lead_days"`
	AvgCycleDays      float64      `json:"avg_cycle_days"`
	ThroughputPerWeek float64      `json:"throughput_per_week"`
	Points            []cyclePoint `json:"points"`
}

func round1(v float64) float64 { return math.Round(v*10) / 10 }

func mean(xs []float64) float64 {
	if len(xs) == 0 {
		return 0
	}
	var sum float64
	for _, x := range xs {
		sum += x
	}
	return sum / float64(len(xs))
}

// percentile returns the p-quantile (0..1) of xs using nearest-rank.
func percentile(xs []float64, p float64) float64 {
	if len(xs) == 0 {
		return 0
	}
	sorted := append([]float64(nil), xs...)
	sort.Float64s(sorted)
	idx := int(math.Ceil(p*float64(len(sorted)))) - 1
	if idx < 0 {
		idx = 0
	}
	if idx >= len(sorted) {
		idx = len(sorted) - 1
	}
	return sorted[idx]
}

func (h *MetricsHandler) cycleTime(w http.ResponseWriter, r *http.Request) {
	days := 90
	if v := r.URL.Query().Get("days"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 365 {
			days = n
		}
	}
	since := pgtype.Timestamptz{
		Time:  time.Now().AddDate(0, 0, -days),
		Valid: true,
	}
	rows, err := h.q.ListCompletedTaskMetrics(r.Context(), since)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	points := make([]cyclePoint, 0, len(rows))
	leads := make([]float64, 0, len(rows))
	cycles := make([]float64, 0, len(rows))
	for _, t := range rows {
		if !t.CompletedAt.Valid {
			continue
		}
		completed := t.CompletedAt.Time
		lead := round1(completed.Sub(t.CreatedAt).Hours() / 24)
		if lead < 0 {
			lead = 0
		}
		p := cyclePoint{
			ID:          t.ID,
			Title:       t.Title,
			CompletedAt: completed,
			LeadDays:    lead,
		}
		leads = append(leads, lead)
		if t.StartDate.Valid && completed.After(t.StartDate.Time) {
			cyc := round1(completed.Sub(t.StartDate.Time).Hours() / 24)
			p.CycleDays = &cyc
			cycles = append(cycles, cyc)
		}
		points = append(points, p)
	}
	weeks := float64(days) / 7
	throughput := 0.0
	if weeks > 0 {
		throughput = round1(float64(len(points)) / weeks)
	}
	writeJSON(w, http.StatusOK, cycleMetricsResponse{
		CompletedCount:    len(points),
		Days:              days,
		AvgLeadDays:       round1(mean(leads)),
		MedianLeadDays:    round1(percentile(leads, 0.5)),
		P85LeadDays:       round1(percentile(leads, 0.85)),
		AvgCycleDays:      round1(mean(cycles)),
		ThroughputPerWeek: throughput,
		Points:            points,
	})
}
