package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// GitHandler serves /api/v1/git — registered repositories and the commit
// activity ingested from their push webhooks. The public webhook endpoint is
// mounted separately (outside auth) on /api/v1/git-webhook/{token}.
type GitHandler struct {
	q *db.Queries
}

// NewGitHandler wires the handler to the query layer.
func NewGitHandler(q *db.Queries) *GitHandler {
	return &GitHandler{q: q}
}

// Routes builds the authed sub-router mounted at /api/v1/git.
func (h *GitHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/repos", h.listRepos)
	r.Post("/repos", h.createRepo)
	r.Delete("/repos/{id}", h.deleteRepo)
	r.Get("/commits", h.listCommits)
	return r
}

// taskRefRe pulls the first `#123` task reference out of a commit message.
var taskRefRe = regexp.MustCompile(`#(\d+)`)

type repoResponse struct {
	ID            int64      `json:"id"`
	Name          string     `json:"name"`
	Provider      string     `json:"provider"`
	URL           string     `json:"url"`
	DefaultBranch string     `json:"default_branch"`
	ProjectID     *int64     `json:"project_id"`
	ProjectName   string     `json:"project_name"`
	WebhookToken  string     `json:"webhook_token"`
	CommitCount   int64      `json:"commit_count"`
	LastCommitAt  *time.Time `json:"last_commit_at"`
	CreatedAt     time.Time  `json:"created_at"`
}

type commitResponse struct {
	ID          int64     `json:"id"`
	RepoID      int64     `json:"repo_id"`
	RepoName    string    `json:"repo_name"`
	Sha         string    `json:"sha"`
	ShortSha    string    `json:"short_sha"`
	Message     string    `json:"message"`
	AuthorName  string    `json:"author_name"`
	AuthorEmail string    `json:"author_email"`
	URL         string    `json:"url"`
	Branch      string    `json:"branch"`
	TaskRef     *int64    `json:"task_ref"`
	TaskTitle   string    `json:"task_title"`
	CommittedAt time.Time `json:"committed_at"`
}

func validGitProvider(s string) string {
	switch s {
	case "github", "gitlab", "bitbucket", "other":
		return s
	default:
		return "github"
	}
}

func shortSha(sha string) string {
	if len(sha) > 7 {
		return sha[:7]
	}
	return sha
}

func (h *GitHandler) listRepos(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListRepos(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]repoResponse, 0, len(rows))
	for _, rp := range rows {
		var last *time.Time
		if t, ok := rp.LastCommitAt.(time.Time); ok {
			last = &t
		}
		out = append(out, repoResponse{
			ID:            rp.ID,
			Name:          rp.Name,
			Provider:      rp.Provider,
			URL:           rp.Url,
			DefaultBranch: rp.DefaultBranch,
			ProjectID:     rp.ProjectID,
			ProjectName:   rp.ProjectName,
			WebhookToken:  rp.WebhookToken,
			CommitCount:   rp.CommitCount,
			LastCommitAt:  last,
			CreatedAt:     rp.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type createRepoBody struct {
	Name          string `json:"name"`
	Provider      string `json:"provider"`
	URL           string `json:"url"`
	DefaultBranch string `json:"default_branch"`
	ProjectID     *int64 `json:"project_id"`
}

func (h *GitHandler) createRepo(w http.ResponseWriter, r *http.Request) {
	var b createRepoBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	branch := strings.TrimSpace(b.DefaultBranch)
	if branch == "" {
		branch = "main"
	}
	row, err := h.q.CreateRepo(r.Context(), db.CreateRepoParams{
		Name:          strings.TrimSpace(b.Name),
		Provider:      validGitProvider(b.Provider),
		Url:           strings.TrimSpace(b.URL),
		DefaultBranch: branch,
		ProjectID:     b.ProjectID,
		WebhookToken:  shareToken(),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, repoResponse{
		ID:            row.ID,
		Name:          row.Name,
		Provider:      row.Provider,
		URL:           row.Url,
		DefaultBranch: row.DefaultBranch,
		ProjectID:     row.ProjectID,
		WebhookToken:  row.WebhookToken,
		CreatedAt:     row.CreatedAt,
	})
}

func (h *GitHandler) deleteRepo(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteRepo(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *GitHandler) listCommits(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListCommits(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]commitResponse, 0, len(rows))
	for _, c := range rows {
		out = append(out, commitResponse{
			ID:          c.ID,
			RepoID:      c.RepoID,
			RepoName:    c.RepoName,
			Sha:         c.Sha,
			ShortSha:    shortSha(c.Sha),
			Message:     c.Message,
			AuthorName:  c.AuthorName,
			AuthorEmail: c.AuthorEmail,
			URL:         c.Url,
			Branch:      c.Branch,
			TaskRef:     c.TaskRef,
			TaskTitle:   c.TaskTitle,
			CommittedAt: c.CommittedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

// gitPushPayload is the subset of a GitHub / GitLab-style push webhook body
// that we ingest. Both providers expose a `commits` array in this shape.
type gitPushPayload struct {
	Ref     string `json:"ref"`
	Commits []struct {
		ID        string `json:"id"`
		Message   string `json:"message"`
		URL       string `json:"url"`
		Timestamp string `json:"timestamp"`
		Author    struct {
			Name  string `json:"name"`
			Email string `json:"email"`
		} `json:"author"`
	} `json:"commits"`
}

// Webhook ingests a push event for the repo identified by the URL token. It is
// mounted publicly (no auth) — the unguessable token is the credential.
func (h *GitHandler) Webhook(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	repo, err := h.q.GetRepoByToken(r.Context(), token)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("unknown repository"))
		return
	}
	var p gitPushPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	branch := strings.TrimPrefix(p.Ref, "refs/heads/")
	ingested := 0
	for _, c := range p.Commits {
		if strings.TrimSpace(c.ID) == "" {
			continue
		}
		when, perr := time.Parse(time.RFC3339, c.Timestamp)
		if perr != nil {
			when = time.Now()
		}
		var taskRef *int64
		if m := taskRefRe.FindStringSubmatch(c.Message); m != nil {
			if n, cerr := strconv.ParseInt(m[1], 10, 64); cerr == nil {
				taskRef = &n
			}
		}
		if err := h.q.InsertCommit(r.Context(), db.InsertCommitParams{
			RepoID:      repo.ID,
			Sha:         c.ID,
			Message:     c.Message,
			AuthorName:  c.Author.Name,
			AuthorEmail: c.Author.Email,
			Url:         c.URL,
			Branch:      branch,
			TaskRef:     taskRef,
			CommittedAt: when,
		}); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		ingested++
	}
	writeJSON(w, http.StatusOK, map[string]any{"ingested": ingested})
}
