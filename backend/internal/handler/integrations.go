package handler

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// apiKeyPrefix tags personal access tokens so the middleware can tell them
// apart from JWT bearer tokens at a glance.
const apiKeyPrefix = "revah_"

// knownProviders is the catalogue of integrations the workspace can connect.
var knownProviders = map[string]bool{
	"slack": true, "github": true, "gitlab": true, "bitbucket": true,
	"google_drive": true, "google_calendar": true, "zoom": true,
	"teams": true, "outlook": true, "dropbox": true, "figma": true,
	"zapier": true,
}

// deliveryProviders push outgoing event payloads to a configured webhook URL.
var deliveryProviders = []string{"slack", "teams", "zapier"}

var webhookClient = &http.Client{Timeout: 6 * time.Second}

// IntegrationHandler serves /api/v1/integrations — the integrations hub: the
// connectable catalogue (Slack, GitHub, …), personal API keys, and outgoing
// webhooks.
type IntegrationHandler struct {
	q *db.Queries
}

// NewIntegrationHandler wires the handler to the query layer.
func NewIntegrationHandler(q *db.Queries) *IntegrationHandler {
	return &IntegrationHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/integrations.
func (h *IntegrationHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.listIntegrations)
	r.Put("/{provider}", h.connect)
	r.Delete("/{provider}", h.disconnect)
	r.Get("/api-keys", h.listKeys)
	r.Post("/api-keys", h.createKey)
	r.Delete("/api-keys/{id}", h.deleteKey)
	r.Get("/webhooks", h.listWebhooks)
	r.Post("/webhooks", h.createWebhook)
	r.Patch("/webhooks/{id}", h.updateWebhook)
	r.Delete("/webhooks/{id}", h.deleteWebhook)
	r.Post("/webhooks/{id}/test", h.testWebhook)
	return r
}

// --- API key middleware ----------------------------------------------------

// APIKeyMiddleware lets a request authenticate with a personal API key (via the
// X-API-Key header or a `revah_` bearer token); anything else falls through to
// the JWT middleware.
func APIKeyMiddleware(q *db.Queries, jwt func(http.Handler) http.Handler) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		jwtNext := jwt(next)
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw := apiKeyFromRequest(r)
			if strings.HasPrefix(raw, apiKeyPrefix) {
				row, err := q.LookupAPIKey(r.Context(), hashToken(raw))
				if err == nil {
					_ = q.TouchAPIKey(r.Context(), row.ID)
					claims := account.Claims{
						UserID: row.UserID,
						Email:  row.Email,
						Name:   row.FullName,
						Role:   row.Role,
					}
					next.ServeHTTP(w, r.WithContext(
						account.WithClaims(r.Context(), claims)))
					return
				}
			}
			jwtNext.ServeHTTP(w, r)
		})
	}
}

func apiKeyFromRequest(r *http.Request) string {
	if k := r.Header.Get("X-API-Key"); k != "" {
		return k
	}
	parts := strings.SplitN(r.Header.Get("Authorization"), " ", 2)
	if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
		return parts[1]
	}
	return ""
}

func hashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

// actorName is the display name of the authenticated user, for event payloads.
func actorName(ctx context.Context) string {
	if c, ok := account.FromContext(ctx); ok {
		if c.Name != "" {
			return c.Name
		}
		return c.Email
	}
	return "Someone"
}

// --- catalogue -------------------------------------------------------------

type integrationResponse struct {
	Provider  string         `json:"provider"`
	Connected bool           `json:"connected"`
	Config    map[string]any `json:"config"`
	UpdatedAt time.Time      `json:"updated_at"`
}

func (h *IntegrationHandler) listIntegrations(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListIntegrations(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]integrationResponse, 0, len(rows))
	for _, row := range rows {
		cfg := map[string]any{}
		_ = json.Unmarshal([]byte(row.Config), &cfg)
		out = append(out, integrationResponse{
			Provider:  row.Provider,
			Connected: row.Connected,
			Config:    cfg,
			UpdatedAt: row.UpdatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *IntegrationHandler) connect(w http.ResponseWriter, r *http.Request) {
	provider := chi.URLParam(r, "provider")
	if !knownProviders[provider] {
		writeError(w, http.StatusBadRequest, errors.New("unknown integration"))
		return
	}
	var b struct {
		Connected bool           `json:"connected"`
		Config    map[string]any `json:"config"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Config == nil {
		b.Config = map[string]any{}
	}
	cfg, _ := json.Marshal(b.Config)
	if err := h.q.UpsertIntegration(r.Context(), db.UpsertIntegrationParams{
		Provider:  provider,
		Connected: b.Connected,
		Config:    string(cfg),
		UpdatedBy: actorOf(r.Context()),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *IntegrationHandler) disconnect(w http.ResponseWriter, r *http.Request) {
	if err := h.q.DeleteIntegration(r.Context(),
		chi.URLParam(r, "provider")); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- API keys --------------------------------------------------------------

type apiKeyResponse struct {
	ID         int64      `json:"id"`
	Name       string     `json:"name"`
	Prefix     string     `json:"prefix"`
	LastUsedAt *time.Time `json:"last_used_at"`
	CreatedAt  time.Time  `json:"created_at"`
}

func (h *IntegrationHandler) listKeys(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	rows, err := h.q.ListAPIKeys(r.Context(), *actor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]apiKeyResponse, 0, len(rows))
	for _, k := range rows {
		var last *time.Time
		if k.LastUsedAt.Valid {
			t := k.LastUsedAt.Time
			last = &t
		}
		out = append(out, apiKeyResponse{
			ID:         k.ID,
			Name:       k.Name,
			Prefix:     k.Prefix,
			LastUsedAt: last,
			CreatedAt:  k.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *IntegrationHandler) createKey(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b struct {
		Name string `json:"name"`
	}
	_ = json.NewDecoder(r.Body).Decode(&b)
	name := strings.TrimSpace(b.Name)
	if name == "" {
		name = "API key"
	}
	token, err := newToken()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	prefix := token[:12]
	row, err := h.q.CreateAPIKey(r.Context(), db.CreateAPIKeyParams{
		UserID:    *actor,
		Name:      name,
		TokenHash: hashToken(token),
		Prefix:    prefix,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	// The full token is returned exactly once, here.
	writeJSON(w, http.StatusCreated, map[string]any{
		"id":         row.ID,
		"name":       name,
		"token":      token,
		"prefix":     prefix,
		"created_at": row.CreatedAt,
	})
}

func (h *IntegrationHandler) deleteKey(w http.ResponseWriter, r *http.Request) {
	actor := actorOf(r.Context())
	if actor == nil {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteAPIKey(r.Context(), db.DeleteAPIKeyParams{
		ID: id, UserID: *actor,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func newToken() (string, error) {
	buf := make([]byte, 20)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return apiKeyPrefix + hex.EncodeToString(buf), nil
}

// --- webhooks --------------------------------------------------------------

type webhookResponse struct {
	ID        int64    `json:"id"`
	URL       string   `json:"url"`
	Events    []string `json:"events"`
	Active    bool     `json:"active"`
	Provider  string   `json:"provider"`
	HasSecret bool     `json:"has_secret"`
}

func webhookFrom(wbk db.Webhook) webhookResponse {
	events := []string{}
	_ = json.Unmarshal([]byte(wbk.Events), &events)
	return webhookResponse{
		ID:        wbk.ID,
		URL:       wbk.Url,
		Events:    events,
		Active:    wbk.Active,
		Provider:  wbk.Provider,
		HasSecret: wbk.Secret != "",
	}
}

func (h *IntegrationHandler) listWebhooks(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListWebhooks(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]webhookResponse, 0, len(rows))
	for _, wbk := range rows {
		out = append(out, webhookFrom(wbk))
	}
	writeJSON(w, http.StatusOK, out)
}

type webhookBody struct {
	URL      string   `json:"url"`
	Secret   string   `json:"secret"`
	Events   []string `json:"events"`
	Active   bool     `json:"active"`
	Provider string   `json:"provider"`
}

func (h *IntegrationHandler) createWebhook(w http.ResponseWriter, r *http.Request) {
	var b webhookBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(b.URL) == "" {
		writeError(w, http.StatusBadRequest, errors.New("a URL is required"))
		return
	}
	events, _ := json.Marshal(b.Events)
	provider := b.Provider
	if provider == "" {
		provider = "custom"
	}
	wbk, err := h.q.CreateWebhook(r.Context(), db.CreateWebhookParams{
		Url:       strings.TrimSpace(b.URL),
		Secret:    b.Secret,
		Events:    string(events),
		Active:    true,
		Provider:  provider,
		CreatedBy: actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, webhookFrom(wbk))
}

func (h *IntegrationHandler) updateWebhook(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b webhookBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	events, _ := json.Marshal(b.Events)
	if err := h.q.UpdateWebhook(r.Context(), db.UpdateWebhookParams{
		ID:     id,
		Url:    strings.TrimSpace(b.URL),
		Events: string(events),
		Active: b.Active,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *IntegrationHandler) deleteWebhook(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteWebhook(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *IntegrationHandler) testWebhook(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	wbk, err := h.q.GetWebhook(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("webhook not found"))
		return
	}
	payload := map[string]any{
		"event": "test",
		"title": "Test delivery",
		"actor": "Revah Management System",
		"time":  time.Now().UTC().Format(time.RFC3339),
	}
	body, _ := json.Marshal(payload)
	deliverTo(wbk.Provider, wbk.Url, wbk.Secret, body,
		"✅ Test delivery from Revah Management System")
	w.WriteHeader(http.StatusNoContent)
}

// --- event delivery --------------------------------------------------------

// dispatchTaskEvent delivers a task event to every active webhook and connected
// delivery integration. Best-effort and asynchronous so it never blocks the
// request that triggered it.
func dispatchTaskEvent(q *db.Queries, event, title, actor, detail string, taskID int64) {
	payload := map[string]any{
		"event":   event,
		"task_id": taskID,
		"title":   title,
		"actor":   actor,
		"detail":  detail,
		"time":    time.Now().UTC().Format(time.RFC3339),
	}
	body, _ := json.Marshal(payload)
	text := eventSummary(event, title, actor)
	go deliver(q, event, body, text)
}

func deliver(q *db.Queries, event string, body []byte, text string) {
	ctx := context.Background()
	if hooks, err := q.ListActiveWebhooks(ctx); err == nil {
		for _, wbk := range hooks {
			if !subscribed(wbk.Events, event) {
				continue
			}
			deliverTo(wbk.Provider, wbk.Url, wbk.Secret, body, text)
		}
	}
	if rows, err := q.ListConnectedByProvider(ctx, deliveryProviders); err == nil {
		for _, row := range rows {
			url := configString(row.Config, "url")
			if url != "" {
				deliverTo(row.Provider, url, "", body, text)
			}
		}
	}
}

// deliverTo POSTs to one endpoint, formatting the body for chat providers that
// expect a `{"text": …}` shape (Slack, Microsoft Teams).
func deliverTo(provider, url, secret string, body []byte, text string) {
	out := body
	if provider == "slack" || provider == "teams" {
		out, _ = json.Marshal(map[string]string{"text": text})
	}
	postJSON(url, out, secret)
}

func postJSON(url string, body []byte, secret string) {
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	if secret != "" {
		mac := hmac.New(sha256.New, []byte(secret))
		_, _ = mac.Write(body)
		req.Header.Set("X-Revah-Signature",
			"sha256="+hex.EncodeToString(mac.Sum(nil)))
	}
	resp, err := webhookClient.Do(req)
	if err == nil {
		_ = resp.Body.Close()
	}
}

// subscribed reports whether a webhook (with a JSON array of event keys)
// listens for event. An empty list means "all events".
func subscribed(eventsJSON, event string) bool {
	var events []string
	_ = json.Unmarshal([]byte(eventsJSON), &events)
	if len(events) == 0 {
		return true
	}
	for _, e := range events {
		if e == event {
			return true
		}
	}
	return false
}

func configString(configJSON, key string) string {
	cfg := map[string]any{}
	_ = json.Unmarshal([]byte(configJSON), &cfg)
	if v, ok := cfg[key].(string); ok {
		return v
	}
	return ""
}

func eventSummary(event, title, actor string) string {
	switch event {
	case "task.created":
		return "🆕 " + actor + " created task “" + title + "”"
	case "task.completed":
		return "✅ " + actor + " completed task “" + title + "”"
	case "task.updated":
		return "🔄 " + actor + " updated task “" + title + "”"
	case "comment.created":
		return "💬 " + actor + " commented on “" + title + "”"
	default:
		return actor + ": " + title
	}
}
