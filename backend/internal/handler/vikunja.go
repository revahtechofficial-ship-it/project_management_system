package handler

import (
	"net/http"
	"net/http/httputil"
	"net/url"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/nexax/backend/internal/vikunja"
)

// VikunjaHandler is the BFF surface over the Vikunja task engine.
type VikunjaHandler struct {
	client *vikunja.Client
}

// NewVikunjaHandler wires the handler to a Vikunja client.
func NewVikunjaHandler(client *vikunja.Client) *VikunjaHandler {
	return &VikunjaHandler{client: client}
}

// Routes builds a sub-router intended to be mounted under /api/v1/vikunja.
func (h *VikunjaHandler) Routes() http.Handler {
	r := chi.NewRouter()

	// Typed/aggregated endpoint (the BFF pattern): the Go backend shapes the
	// response instead of exposing Vikunja's raw payload.
	r.Get("/projects", h.listProjects)

	// Transparent passthrough for everything else, so the client can reach any
	// Vikunja v1 endpoint during development. The caller's Authorization header
	// is forwarded as-is:
	//   GET /api/v1/vikunja/proxy/tasks/all  ->  {vikunja}/api/v1/tasks/all
	r.Handle("/proxy/*", h.proxy())

	return r
}

func (h *VikunjaHandler) listProjects(w http.ResponseWriter, r *http.Request) {
	projects, err := h.client.ListProjects(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, projects)
}

// proxy returns a reverse proxy that rewrites /api/v1/vikunja/proxy/<rest>
// to {vikunja}/api/v1/<rest>.
func (h *VikunjaHandler) proxy() http.Handler {
	target, _ := url.Parse(h.client.BaseURL() + "/api/v1")
	rp := httputil.NewSingleHostReverseProxy(target)

	// Preserve the upstream Host so Vikunja builds correct URLs.
	director := rp.Director
	rp.Director = func(req *http.Request) {
		director(req)
		req.Host = target.Host
	}

	return http.StripPrefix("/api/v1/vikunja/proxy", rp)
}
