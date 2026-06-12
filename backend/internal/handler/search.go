package handler

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// SearchHandler serves the workspace-wide search endpoint (GET /api/v1/search).
type SearchHandler struct {
	q *db.Queries
}

// NewSearchHandler wires the handler to the generated query layer.
func NewSearchHandler(q *db.Queries) *SearchHandler {
	return &SearchHandler{q: q}
}

// projectHit is the lightweight project shape returned by search.
type projectHit struct {
	ID      int64      `json:"id"`
	Name    string     `json:"name"`
	Status  string     `json:"status"`
	DueDate *time.Time `json:"due_date"`
}

type searchResponse struct {
	Tasks    []taskResponse `json:"tasks"`
	Projects []projectHit   `json:"projects"`
}

// Search matches the query against tasks (title, description, project, tags)
// and projects (name, description). Tasks are paginated via limit/offset;
// projects are only returned on the first page.
func (h *SearchHandler) Search(w http.ResponseWriter, r *http.Request) {
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	limit := clampInt(parseIntDefault(r.URL.Query().Get("limit"), 20), 1, 50)
	offset := maxInt(parseIntDefault(r.URL.Query().Get("offset"), 0), 0)

	out := searchResponse{Tasks: []taskResponse{}, Projects: []projectHit{}}
	if query == "" {
		writeJSON(w, http.StatusOK, out)
		return
	}

	taskRows, err := h.q.SearchTasks(r.Context(), db.SearchTasksParams{
		Query: &query,
		Lim:   int32(limit),
		Off:   int32(offset),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	for _, row := range taskRows {
		out.Tasks = append(out.Tasks, taskFromSearchRow(row))
	}

	// Projects are a small set; only fetch them for the first page of results.
	if offset == 0 {
		projRows, err := h.q.SearchProjects(r.Context(), db.SearchProjectsParams{
			Query: &query,
			Lim:   8,
		})
		if err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		for _, p := range projRows {
			out.Projects = append(out.Projects, projectHit{
				ID:      p.ID,
				Name:    p.Name,
				Status:  p.Status,
				DueDate: tsPtr(p.DueDate),
			})
		}
	}
	writeJSON(w, http.StatusOK, out)
}

func taskFromSearchRow(r db.SearchTasksRow) taskResponse {
	return taskResponse{
		ID:               r.ID,
		Title:            r.Title,
		Description:      r.Description,
		Done:             r.Done,
		Status:           r.Status,
		CreatedAt:        r.CreatedAt,
		UpdatedAt:        r.UpdatedAt,
		ProjectID:        r.ProjectID,
		AssigneeID:       r.AssigneeID,
		ProjectName:      r.ProjectName,
		AssigneeName:     r.AssigneeName,
		StartDate:        tsPtr(r.StartDate),
		DueDate:          tsPtr(r.DueDate),
		ParentID:         r.ParentID,
		Recurrence:       r.Recurrence,
		SubtaskCount:     r.SubtaskCount,
		SubtaskDoneCount: r.SubtaskDoneCount,
		BaselineStart:    tsPtr(r.BaselineStart),
		BaselineDue:      tsPtr(r.BaselineDue),
		Priority:         r.Priority,
		Tags:             r.Tags,
	}
}

func parseIntDefault(s string, def int) int {
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}

func clampInt(n, lo, hi int) int {
	if n < lo {
		return lo
	}
	if n > hi {
		return hi
	}
	return n
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}
