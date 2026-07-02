package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// InboundHandler turns forwarded emails into tasks. It is mounted publicly
// (outside the app JWT) and guarded by a shared secret, so any mail forwarder
// — e.g. a Gmail Apps Script on the workspace account — can post to it.
type InboundHandler struct {
	q      *db.Queries
	secret string
}

// NewInboundHandler wires the handler with the shared secret from config.
func NewInboundHandler(q *db.Queries, secret string) *InboundHandler {
	return &InboundHandler{q: q, secret: secret}
}

// A project id encoded in the recipient (…+p42@…) or the subject ([p42]/[#42]).
var (
	projectInAddr    = regexp.MustCompile(`(?i)p(\d+)@`)
	projectInSubject = regexp.MustCompile(`(?i)\[#?p?(\d+)\]`)
)

type inboundEmail struct {
	To      string `json:"to"`
	From    string `json:"from"`
	Subject string `json:"subject"`
	Text    string `json:"text"`
}

// Handle creates a task from a forwarded email.
func (h *InboundHandler) Handle(w http.ResponseWriter, r *http.Request) {
	if h.secret == "" {
		writeError(w, http.StatusServiceUnavailable,
			errors.New("inbound email not configured"))
		return
	}
	provided := r.Header.Get("X-Inbound-Secret")
	if provided == "" {
		provided = r.URL.Query().Get("secret")
	}
	if provided != h.secret {
		writeError(w, http.StatusUnauthorized, errors.New("bad secret"))
		return
	}

	msg := h.parse(r)
	subject := strings.TrimSpace(msg.Subject)
	title := subject
	if title == "" {
		title = firstLine(msg.Text)
	}
	if title == "" {
		title = "(no subject)"
	}
	if len(title) > 200 {
		title = title[:200]
	}

	desc := strings.TrimSpace(msg.Text)
	if strings.TrimSpace(msg.From) != "" {
		if desc != "" {
			desc += "\n\n"
		}
		desc += "— via email from " + strings.TrimSpace(msg.From)
	}

	projectID := parseProjectID(msg.To, subject)

	params := db.CreateTaskParams{
		Title:       title,
		Description: desc,
		ProjectID:   projectID,
		Status:      statusOrTodo(""),
		Recurrence:  "none",
		Priority:    priorityOrNone(""),
		Tags:        []string{},
		IssueType:   "task",
		Severity:    "none",
	}
	task, err := h.q.CreateTask(r.Context(), params)
	if err != nil && projectID != nil {
		// The project id may be stale — file the task without a project.
		params.ProjectID = nil
		task, err = h.q.CreateTask(r.Context(), params)
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	logActivity(r.Context(), h.q, task.ID, "created", "from email")
	writeJSON(w, http.StatusOK, map[string]any{
		"id": task.ID, "title": task.Title,
	})
}

// parse reads the email from a JSON body, or from form fields (matching common
// provider webhooks: SendGrid's `text`, Mailgun's `body-plain`, etc.).
func (h *InboundHandler) parse(r *http.Request) inboundEmail {
	if strings.Contains(r.Header.Get("Content-Type"), "application/json") {
		var m inboundEmail
		_ = json.NewDecoder(r.Body).Decode(&m)
		return m
	}
	_ = r.ParseForm()
	get := func(keys ...string) string {
		for _, k := range keys {
			if v := r.FormValue(k); v != "" {
				return v
			}
		}
		return ""
	}
	return inboundEmail{
		To:      get("to", "recipient"),
		From:    get("from", "sender"),
		Subject: get("subject"),
		Text:    get("text", "body-plain", "body"),
	}
}

func parseProjectID(to, subject string) *int64 {
	for _, m := range [][]string{
		projectInAddr.FindStringSubmatch(to),
		projectInSubject.FindStringSubmatch(subject),
	} {
		if m != nil {
			if id, err := strconv.ParseInt(m[1], 10, 64); err == nil {
				return &id
			}
		}
	}
	return nil
}

func firstLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		s = s[:i]
	}
	if len(s) > 120 {
		s = s[:120]
	}
	return strings.TrimSpace(s)
}
