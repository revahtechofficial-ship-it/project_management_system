package handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/ai"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// AIHandler serves /api/v1/ai — the Claude-powered assistant: chat, a writing
// assistant, project summaries, task creation, knowledge search and meeting
// notes. When no API key is configured every endpoint returns a friendly 503.
type AIHandler struct {
	q  *db.Queries
	ai *ai.Client
}

// NewAIHandler wires the handler to the query layer and the AI client.
func NewAIHandler(q *db.Queries, client *ai.Client) *AIHandler {
	return &AIHandler{q: q, ai: client}
}

// Routes builds the sub-router mounted at /api/v1/ai.
func (h *AIHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/status", h.status)
	r.Post("/chat", h.chat)
	r.Post("/write", h.write)
	r.Post("/summarize", h.summarize)
	r.Post("/tasks", h.createTasks)
	r.Post("/search", h.search)
	r.Post("/meeting-notes", h.meetingNotes)
	return r
}

func (h *AIHandler) notConfigured(w http.ResponseWriter) {
	writeJSON(w, http.StatusServiceUnavailable, map[string]any{
		"error": "AI is not configured. Set ANTHROPIC_API_KEY on the backend.",
	})
}

func (h *AIHandler) status(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"configured": h.ai.Configured(),
		"model":      h.ai.Model(),
	})
}

const assistantSystem = "You are the AI assistant inside Revah Management " +
	"System, an internal project and task management app for Revah Tech (an IT " +
	"company). Be concise, practical and friendly. Use Markdown. When you don't " +
	"have enough information, say so briefly."

// --- chat ------------------------------------------------------------------

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

func (h *AIHandler) chat(w http.ResponseWriter, r *http.Request) {
	if !h.ai.Configured() {
		h.notConfigured(w)
		return
	}
	var b struct {
		Messages []chatMessage `json:"messages"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	msgs := make([]ai.Message, 0, len(b.Messages))
	for _, m := range b.Messages {
		msgs = append(msgs, ai.Message{Role: m.Role, Text: m.Content})
	}
	reply, err := h.ai.Complete(r.Context(), assistantSystem, msgs, 4096)
	if err != nil {
		h.aiError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"reply": reply})
}

// --- writing assistant -----------------------------------------------------

func writeSystem(action string) string {
	switch action {
	case "improve":
		return "Rewrite the user's text to be clearer and more polished, " +
			"keeping the same meaning and language. Reply with only the rewritten text."
	case "shorten":
		return "Make the user's text more concise without losing key meaning. " +
			"Reply with only the shortened text."
	case "expand":
		return "Expand the user's text with helpful detail and structure. " +
			"Reply with only the expanded text."
	case "fix":
		return "Fix spelling, grammar and punctuation in the user's text. " +
			"Keep the wording otherwise unchanged. Reply with only the corrected text."
	case "professional":
		return "Rewrite the user's text in a professional, business-appropriate " +
			"tone. Reply with only the rewritten text."
	case "summarize":
		return "Summarize the user's text into a few short bullet points. " +
			"Reply with only the summary."
	default:
		return "Improve the user's text. Reply with only the result."
	}
}

func (h *AIHandler) write(w http.ResponseWriter, r *http.Request) {
	if !h.ai.Configured() {
		h.notConfigured(w)
		return
	}
	var b struct {
		Action string `json:"action"`
		Text   string `json:"text"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Text) == "" {
		writeError(w, http.StatusBadRequest, errors.New("text is required"))
		return
	}
	out, err := h.ai.Ask(r.Context(), writeSystem(b.Action), b.Text, 4096)
	if err != nil {
		h.aiError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"result": out})
}

// --- project summary -------------------------------------------------------

func (h *AIHandler) summarize(w http.ResponseWriter, r *http.Request) {
	if !h.ai.Configured() {
		h.notConfigured(w)
		return
	}
	var b struct {
		ProjectID *int64 `json:"project_id"`
	}
	_ = json.NewDecoder(r.Body).Decode(&b)
	rows, err := h.q.ListTasks(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	var sb strings.Builder
	name := "the workspace"
	count := 0
	for _, t := range rows {
		if b.ProjectID != nil && (t.ProjectID == nil || *t.ProjectID != *b.ProjectID) {
			continue
		}
		if b.ProjectID != nil && t.ProjectName != nil {
			name = *t.ProjectName
		}
		status := t.Status
		if t.Done {
			status = "done"
		}
		fmt.Fprintf(&sb, "- [%s] %s (priority: %s)\n", status, t.Title, t.Priority)
		count++
		if count >= 200 {
			break
		}
	}
	if count == 0 {
		writeJSON(w, http.StatusOK, map[string]any{
			"summary": "There are no tasks to summarize yet.",
		})
		return
	}
	prompt := fmt.Sprintf(
		"Write a short status summary for %q based on these tasks. Cover overall "+
			"progress, what's in flight, blockers or risks (overdue/urgent work), "+
			"and 2-3 suggested next steps. Use Markdown.\n\nTasks:\n%s",
		name, sb.String())
	out, err := h.ai.Ask(r.Context(), assistantSystem, prompt, 2048)
	if err != nil {
		h.aiError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"summary": out})
}

// --- AI task creation ------------------------------------------------------

type aiTask struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Priority    string `json:"priority"`
}

func (h *AIHandler) createTasks(w http.ResponseWriter, r *http.Request) {
	if !h.ai.Configured() {
		h.notConfigured(w)
		return
	}
	var b struct {
		Prompt    string `json:"prompt"`
		ProjectID *int64 `json:"project_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Prompt) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a prompt is required"))
		return
	}
	system := "You turn a request into a list of actionable tasks. Respond with " +
		"ONLY a JSON array (no prose, no code fences) of objects with keys: " +
		"\"title\" (string), \"description\" (string, may be empty), \"priority\" " +
		"(one of none, low, normal, high, urgent). Keep titles short and concrete."
	out, err := h.ai.Ask(r.Context(), system, b.Prompt, 4096)
	if err != nil {
		h.aiError(w, err)
		return
	}
	var parsed []aiTask
	if err := json.Unmarshal([]byte(stripFences(out)), &parsed); err != nil {
		writeError(w, http.StatusBadGateway,
			errors.New("the AI response could not be parsed as tasks"))
		return
	}
	created := make([]map[string]any, 0, len(parsed))
	for _, t := range parsed {
		if strings.TrimSpace(t.Title) == "" {
			continue
		}
		task, err := h.q.CreateTask(r.Context(), db.CreateTaskParams{
			Title:       t.Title,
			Description: t.Description,
			ProjectID:   b.ProjectID,
			Status:      statusOrTodo(""),
			Recurrence:  "none",
			Priority:    priorityOrNone(t.Priority),
			Tags:        []string{},
			IssueType:   "task",
			Severity:    "none",
		})
		if err != nil {
			continue
		}
		logActivity(r.Context(), h.q, task.ID, "created", "by AI")
		created = append(created, map[string]any{"id": task.ID, "title": task.Title})
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"created": created, "count": len(created),
	})
}

// --- knowledge search ------------------------------------------------------

func (h *AIHandler) search(w http.ResponseWriter, r *http.Request) {
	if !h.ai.Configured() {
		h.notConfigured(w)
		return
	}
	var b struct {
		Query string `json:"query"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Query) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a query is required"))
		return
	}
	rows, err := h.q.ListTasks(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	var sb strings.Builder
	for i, t := range rows {
		if i >= 150 {
			break
		}
		project := ""
		if t.ProjectName != nil {
			project = " · " + *t.ProjectName
		}
		desc := t.Description
		if len(desc) > 160 {
			desc = desc[:160]
		}
		fmt.Fprintf(&sb, "- %s [%s]%s — %s\n", t.Title, t.Status, project, desc)
	}
	system := "You answer questions using ONLY the workspace data provided. " +
		"Cite the task titles you used. If the answer isn't in the data, say you " +
		"couldn't find it. Use Markdown."
	prompt := fmt.Sprintf("Question: %s\n\nWorkspace tasks:\n%s", b.Query, sb.String())
	out, err := h.ai.Ask(r.Context(), system, prompt, 2048)
	if err != nil {
		h.aiError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"answer": out})
}

// --- meeting notes ---------------------------------------------------------

func (h *AIHandler) meetingNotes(w http.ResponseWriter, r *http.Request) {
	if !h.ai.Configured() {
		h.notConfigured(w)
		return
	}
	var b struct {
		Notes string `json:"notes"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.Notes) == "" {
		writeError(w, http.StatusBadRequest, errors.New("notes are required"))
		return
	}
	system := "You turn raw meeting notes into a clean summary. Respond in " +
		"Markdown with a short ## Summary section followed by a ## Action items " +
		"section as a checklist (- [ ] item). Be specific and concise."
	out, err := h.ai.Ask(r.Context(), system, b.Notes, 2048)
	if err != nil {
		h.aiError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"result": out})
}

// --- helpers ---------------------------------------------------------------

func (h *AIHandler) aiError(w http.ResponseWriter, err error) {
	if errors.Is(err, ai.ErrNotConfigured) {
		h.notConfigured(w)
		return
	}
	writeError(w, http.StatusBadGateway,
		errors.New("the AI service is unavailable right now"))
}

// stripFences removes a leading/trailing Markdown code fence if present.
func stripFences(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "```") {
		if i := strings.IndexByte(s, '\n'); i >= 0 {
			s = s[i+1:]
		}
		s = strings.TrimSuffix(strings.TrimSpace(s), "```")
	}
	return strings.TrimSpace(s)
}
