// Command server is the Nexax backend HTTP API: a Chi router over a pgx
// connection pool, with schema migrations applied at startup via goose.
package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib" // registers the "pgx" database/sql driver for goose
	"github.com/pressly/goose/v3"

	"github.com/revah-tech/nexax/backend/internal/auth"
	"github.com/revah-tech/nexax/backend/internal/config"
	"github.com/revah-tech/nexax/backend/internal/db"
	"github.com/revah-tech/nexax/backend/internal/handler"
	"github.com/revah-tech/nexax/backend/internal/vikunja"
	"github.com/revah-tech/nexax/backend/migrations"
)

func main() {
	cfg := config.Load()

	if err := runMigrations(cfg.DatabaseURL); err != nil {
		log.Fatalf("migrations: %v", err)
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect db: %v", err)
	}
	defer pool.Close()

	queries := db.New(pool)
	vk := vikunja.NewClient(cfg.VikunjaBaseURL)

	// OIDC token verifier. Non-fatal if the issuer is unreachable so the BFF
	// still starts; protected routes then return 503 until auth is available.
	var verifier *auth.Verifier
	if v, err := auth.NewVerifier(ctx, cfg.OIDCIssuer); err != nil {
		log.Printf("WARNING: OIDC auth disabled (issuer %s unreachable): %v", cfg.OIDCIssuer, err)
	} else {
		verifier = v
		log.Printf("OIDC auth enabled (issuer %s)", cfg.OIDCIssuer)
	}

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{cfg.CORSOrigin},
		AllowedMethods:   []string{"GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		if err := pool.Ping(r.Context()); err != nil {
			http.Error(w, "db unavailable", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
	})

	r.Mount("/api/v1/tasks", handler.NewTaskHandler(queries).Routes())
	r.Mount("/api/v1/vikunja", handler.NewVikunjaHandler(vk).Routes())

	// Protected: requires a valid Keycloak token. (Existing routes stay open
	// until the Flutter login flow lands in Phase 3.)
	if verifier != nil {
		r.With(verifier.Middleware).Get("/api/v1/me", handler.Me)
	} else {
		r.Get("/api/v1/me", func(w http.ResponseWriter, _ *http.Request) {
			http.Error(w, "auth not configured", http.StatusServiceUnavailable)
		})
	}

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("nexax backend listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	// Block until an interrupt/termination signal, then shut down gracefully.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	log.Println("shutting down...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
}

// runMigrations applies all pending goose migrations embedded in the binary,
// using a short-lived database/sql connection (goose requires *sql.DB).
func runMigrations(databaseURL string) error {
	sqlDB, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return err
	}
	defer sqlDB.Close()

	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		return err
	}
	return goose.Up(sqlDB, ".")
}
