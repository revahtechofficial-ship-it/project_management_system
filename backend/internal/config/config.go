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
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
