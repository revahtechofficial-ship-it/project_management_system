// Package vikunja is a thin client for the Vikunja REST API (v1). The Go backend
// acts as a backend-for-frontend (BFF): it calls Vikunja on the user's behalf,
// forwarding the user's Authorization header.
package vikunja

import (
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

// Project is a subset of a Vikunja project.
type Project struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	IsArchived  bool   `json:"is_archived"`
}

// ListProjects returns the projects visible to the user identified by authHeader
// (the full "Authorization" header value, e.g. "Bearer <token>").
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
