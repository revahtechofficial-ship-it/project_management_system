// Package config loads runtime configuration from environment variables, with a
// .env file as an optional convenience during local development.
package config

import (
	"os"

	"github.com/joho/godotenv"
)

// Config holds all runtime settings for the server.
type Config struct {
	// DatabaseURL is a libpq/pgx connection string.
	DatabaseURL string
	// Port is the TCP port the HTTP server listens on.
	Port string
	// CORSOrigin is the allowed browser origin for the Flutter web client.
	// Use "*" for local development; set the real origin in production.
	CORSOrigin string
	// VikunjaBaseURL is the Vikunja instance this backend proxies/aggregates
	// (BFF). No trailing slash required.
	VikunjaBaseURL string
	// OIDCIssuer is the Keycloak realm issuer URL used to verify bearer tokens.
	OIDCIssuer string

	// JWTSecret signs the app's own (custom-auth) session JWTs.
	JWTSecret string
	// AppName is used in OTP email subjects/bodies.
	AppName string
	// SMTP settings for sending OTP emails. If SMTPHost/SMTPFrom are empty, the
	// email sender logs codes to stdout instead (dev mode).
	SMTPHost string
	SMTPPort string
	SMTPUser string
	SMTPPass string
	SMTPFrom string

	// Resend (https://resend.com) sends OTP email over HTTPS instead of SMTP.
	// Preferred on hosts that block outbound SMTP ports (e.g. Render's free
	// tier). When ResendAPIKey is set it takes precedence over SMTP. ResendFrom
	// is the verified sender address, e.g. "noreply@yourdomain.com".
	ResendAPIKey string
	ResendFrom   string

	// UploadDir is where task file attachments are stored on disk.
	UploadDir string

	// LiveKit powers voice/video calls. LiveKitURL is the ws(s) URL the browser
	// connects to; the key/secret sign join tokens. When the key or secret is
	// empty, the call endpoints report that calling is disabled.
	LiveKitURL       string
	LiveKitAPIKey    string
	LiveKitAPISecret string

	// AnthropicAPIKey powers the AI assistant (Claude). When empty, the AI
	// endpoints report that AI is not configured. AIModel is the Claude model
	// id (defaults to Opus 4.8).
	AnthropicAPIKey string
	AIModel         string

	// InboundEmailSecret guards the public email-to-task webhook
	// (POST /api/v1/inbound/email). When empty the webhook is disabled; when
	// set, callers must present it via the ?secret= query or X-Inbound-Secret
	// header. Point a mail forwarder (e.g. a Gmail Apps Script) at the webhook.
	InboundEmailSecret string
}

// Load reads configuration from the environment. A .env file in the working
// directory is loaded first if present, but real environment variables always
// take precedence.
func Load() Config {
	// .env is optional — ignore the error when it is absent.
	_ = godotenv.Load()

	return Config{
		DatabaseURL:    getenv("DATABASE_URL", "postgres://revahms:revahms@localhost:5432/revahms?sslmode=disable"),
		Port:           getenv("PORT", "8080"),
		CORSOrigin:     getenv("CORS_ORIGIN", "*"),
		VikunjaBaseURL: getenv("VIKUNJA_BASE_URL", "http://localhost:3456"),
		OIDCIssuer:     getenv("OIDC_ISSUER", "http://host.docker.internal:8088/realms/revahms"),
		JWTSecret:      getenv("JWT_SECRET", "dev-insecure-change-me"),
		AppName:        getenv("APP_NAME", "Revah Management System"),
		SMTPHost:       getenv("SMTP_HOST", ""),
		SMTPPort:       getenv("SMTP_PORT", "587"),
		SMTPUser:       getenv("SMTP_USER", ""),
		SMTPPass:       getenv("SMTP_PASS", ""),
		SMTPFrom:       getenv("SMTP_FROM", ""),
		ResendAPIKey:   getenv("RESEND_API_KEY", ""),
		ResendFrom:     getenv("RESEND_FROM", ""),
		UploadDir:      getenv("UPLOAD_DIR", "./uploads"),
		// Defaults match `livekit-server --dev` (devkey/secret on :7880).
		LiveKitURL:         getenv("LIVEKIT_URL", "ws://localhost:7880"),
		LiveKitAPIKey:      getenv("LIVEKIT_API_KEY", "devkey"),
		LiveKitAPISecret:   getenv("LIVEKIT_API_SECRET", "secret"),
		AnthropicAPIKey:    getenv("ANTHROPIC_API_KEY", ""),
		AIModel:            getenv("AI_MODEL", "claude-opus-4-8"),
		InboundEmailSecret: getenv("INBOUND_EMAIL_SECRET", ""),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
