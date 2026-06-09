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
}

// Load reads configuration from the environment. A .env file in the working
// directory is loaded first if present, but real environment variables always
// take precedence.
func Load() Config {
	// .env is optional — ignore the error when it is absent.
	_ = godotenv.Load()

	return Config{
		DatabaseURL:    getenv("DATABASE_URL", "postgres://nexax:nexax@localhost:5432/nexax?sslmode=disable"),
		Port:           getenv("PORT", "8080"),
		CORSOrigin:     getenv("CORS_ORIGIN", "*"),
		VikunjaBaseURL: getenv("VIKUNJA_BASE_URL", "http://localhost:3456"),
		OIDCIssuer:     getenv("OIDC_ISSUER", "http://localhost:8088/realms/nexax"),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
