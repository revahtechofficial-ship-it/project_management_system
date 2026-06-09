package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httputil"
	"net/url"

	"github.com/revah-tech/revahms/backend/internal/auth"
	"github.com/revah-tech/revahms/backend/internal/vikunja"
)

// vikunjaProvider is the Keycloak OIDC provider key configured in Vikunja.
const vikunjaProvider = "keycloak"

// VikunjaHandler is the BFF surface over the Vikunja task engine. Every route
// is mounted behind the auth middleware, so the caller's identity (Keycloak
// subject) is always available; it uses that to look up the user's Vikunja
// token from the session store.
type VikunjaHandler struct {
	client   *vikunja.Client
	sessions *vikunja.SessionStore
}

// NewVikunjaHandler wires the handler to a Vikunja client and session store.
func NewVikunjaHandler(client *vikunja.Client, sessions *vikunja.SessionStore) *VikunjaHandler {
	return &VikunjaHandler{client: client, sessions: sessions}
}

type sessionRequest struct {
	Code        string `json:"code"`
	RedirectURI string `json:"redirect_uri"`
}

// EstablishSession exchanges a Keycloak auth code (obtained by the client for
// the 'vikunja' OIDC client) for a Vikunja JWT and caches it for this user.
func (h *VikunjaHandler) EstablishSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.FromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("not authenticated"))
		return
	}
	var body sessionRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if body.Code == "" || body.RedirectURI == "" {
		writeError(w, http.StatusBadRequest, errors.New("code and redirect_uri are required"))
		return
	}
	token, err := h.client.Login(r.Context(), vikunjaProvider, body.Code, body.RedirectURI)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	h.sessions.Set(claims.Subject, token)
	w.WriteHeader(http.StatusNoContent)
}

// ListProjects returns the user's Vikunja projects via their cached token.
func (h *VikunjaHandler) ListProjects(w http.ResponseWriter, r *http.Request) {
	token, ok := h.userToken(r)
	if !ok {
		writeError(w, http.StatusPreconditionRequired,
			errors.New("vikunja session not established"))
		return
	}
	projects, err := h.client.ListProjects(r.Context(), "Bearer "+token)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, projects)
}

// Proxy passes requests through to Vikunja using the user's cached token,
// rewriting /api/v1/vikunja/proxy/<rest> -> {vikunja}/api/v1/<rest>.
func (h *VikunjaHandler) Proxy() http.Handler {
	target, _ := url.Parse(h.client.BaseURL() + "/api/v1")
	rp := httputil.NewSingleHostReverseProxy(target)
	director := rp.Director
	rp.Director = func(req *http.Request) {
		director(req)
		req.Host = target.Host
	}
	stripped := http.StripPrefix("/api/v1/vikunja/proxy", rp)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, ok := h.userToken(r)
		if !ok {
			writeError(w, http.StatusPreconditionRequired,
				errors.New("vikunja session not established"))
			return
		}
		// Swap the inbound Keycloak token for the user's Vikunja token.
		r.Header.Set("Authorization", "Bearer "+token)
		stripped.ServeHTTP(w, r)
	})
}

func (h *VikunjaHandler) userToken(r *http.Request) (string, bool) {
	claims, ok := auth.FromContext(r.Context())
	if !ok {
		return "", false
	}
	return h.sessions.Get(claims.Subject)
}
