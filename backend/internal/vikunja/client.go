// Package vikunja is a thin client for the Vikunja REST API (v1). The Go backend
// acts as a backend-for-frontend (BFF): it calls Vikunja on the user's behalf
// using a per-user Vikunja token obtained via OIDC (see Login + SessionStore).
package vikunja

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Client talks to a Vikunja instance.
type Client struct {
	baseURL string
	http    *http.Client
}

// NewClient builds a client for the given Vikunja base URL (e.g. http://localhost:3456).
func NewClient(baseURL string) *Client {
	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		http:    &http.Client{Timeout: 15 * time.Second},
	}
}

// BaseURL returns the configured base URL with no trailing slash.
func (c *Client) BaseURL() string { return c.baseURL }

// Login exchanges an OIDC authorization code (obtained for Vikunja's client)
// for a Vikunja JWT via Vikunja's OpenID callback. provider is the configured
// provider key (e.g. "keycloak"); redirectURL must match the one used to obtain
// the code.
func (c *Client) Login(ctx context.Context, provider, code, redirectURL string) (string, error) {
	payload, err := json.Marshal(map[string]string{
		"code":         code,
		"redirect_url": redirectURL,
	})
	if err != nil {
		return "", err
	}
	url := c.baseURL + "/api/v1/auth/openid/" + provider + "/callback"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("vikunja openid callback: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 2<<10))
		return "", fmt.Errorf("vikunja openid callback %d: %s", resp.StatusCode, strings.TrimSpace(string(b)))
	}

	var out struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", fmt.Errorf("decode vikunja token: %w", err)
	}
	if out.Token == "" {
		return "", fmt.Errorf("vikunja returned an empty token")
	}
	return out.Token, nil
}

// Project is a subset of a Vikunja project.
type Project struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	IsArchived  bool   `json:"is_archived"`
}

// ListProjects returns the projects visible to the user identified by authHeader
// (the full "Authorization" header value, e.g. "Bearer <vikunja-token>").
func (c *Client) ListProjects(ctx context.Context, authHeader string) ([]Project, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/api/v1/projects", nil)
	if err != nil {
		return nil, err
	}
	if authHeader != "" {
		req.Header.Set("Authorization", authHeader)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("call vikunja: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 2<<10))
		return nil, fmt.Errorf("vikunja returned %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	var projects []Project
	if err := json.NewDecoder(resp.Body).Decode(&projects); err != nil {
		return nil, fmt.Errorf("decode vikunja response: %w", err)
	}
	return projects, nil
}
