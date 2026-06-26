// Package ai wraps the Anthropic (Claude) API for the in-app AI assistant.
// When no API key is configured the client reports that AI is unavailable and
// every call returns ErrNotConfigured rather than panicking.
package ai

import (
	"context"
	"errors"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

// ErrNotConfigured is returned by all calls when no ANTHROPIC_API_KEY is set.
var ErrNotConfigured = errors.New("AI is not configured")

// Message is one turn of a conversation.
type Message struct {
	Role string // "user" | "assistant"
	Text string
}

// Client is a thin wrapper over the Anthropic Messages API.
type Client struct {
	api   anthropic.Client
	model anthropic.Model
	ok    bool
}

// New builds a client. An empty apiKey yields a disabled client whose calls
// return ErrNotConfigured. An empty model defaults to Claude Opus 4.8.
func New(apiKey, model string) *Client {
	if apiKey == "" {
		return &Client{ok: false}
	}
	if model == "" {
		model = "claude-opus-4-8"
	}
	return &Client{
		api:   anthropic.NewClient(option.WithAPIKey(apiKey)),
		model: anthropic.Model(model),
		ok:    true,
	}
}

// Configured reports whether an API key is available.
func (c *Client) Configured() bool { return c != nil && c.ok }

// Model returns the configured model id (empty when not configured).
func (c *Client) Model() string {
	if !c.Configured() {
		return ""
	}
	return string(c.model)
}

// Complete sends a system prompt plus a conversation and returns the assistant
// text. maxTokens caps the response length.
func (c *Client) Complete(ctx context.Context, system string, msgs []Message, maxTokens int64) (string, error) {
	if !c.Configured() {
		return "", ErrNotConfigured
	}
	params := anthropic.MessageNewParams{
		Model:     c.model,
		MaxTokens: maxTokens,
		Messages:  toMessages(msgs),
	}
	if system != "" {
		params.System = []anthropic.TextBlockParam{{Text: system}}
	}
	resp, err := c.api.Messages.New(ctx, params)
	if err != nil {
		return "", err
	}
	var out string
	for _, block := range resp.Content {
		if t, ok := block.AsAny().(anthropic.TextBlock); ok {
			out += t.Text
		}
	}
	return out, nil
}

// Ask is a convenience for a single user prompt with a system instruction.
func (c *Client) Ask(ctx context.Context, system, prompt string, maxTokens int64) (string, error) {
	return c.Complete(ctx, system, []Message{{Role: "user", Text: prompt}}, maxTokens)
}

func toMessages(msgs []Message) []anthropic.MessageParam {
	out := make([]anthropic.MessageParam, 0, len(msgs))
	for _, m := range msgs {
		if m.Text == "" {
			continue
		}
		if m.Role == "assistant" {
			out = append(out, anthropic.NewAssistantMessage(anthropic.NewTextBlock(m.Text)))
		} else {
			out = append(out, anthropic.NewUserMessage(anthropic.NewTextBlock(m.Text)))
		}
	}
	return out
}
