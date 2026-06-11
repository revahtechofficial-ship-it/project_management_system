// Command server is the Revah Management System backend HTTP API: a Chi router over a pgx
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

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/auth"
	"github.com/revah-tech/revahms/backend/internal/config"
	"github.com/revah-tech/revahms/backend/internal/db"
	"github.com/revah-tech/revahms/backend/internal/email"
	"github.com/revah-tech/revahms/backend/internal/handler"
	"github.com/revah-tech/revahms/backend/internal/vikunja"
	"github.com/revah-tech/revahms/backend/migrations"
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
	vkSessions := vikunja.NewSessionStore()

	// Custom email/password auth: users in Postgres, app-issued JWT, OTP email.
	mailer := email.NewSender(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPass, cfg.SMTPFrom, cfg.AppName)
	appTokens := account.NewTokens(cfg.JWTSecret)
	accountHandler := handler.NewAccountHandler(account.NewService(queries, appTokens, mailer))

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

	// Custom email/password authentication (public endpoints + JWT-protected /me).
	r.Route("/api/v1/auth", func(sub chi.Router) {
		sub.Post("/register", accountHandler.Register)
		sub.Post("/verify-email", accountHandler.VerifyEmail)
		sub.Post("/login", accountHandler.Login)
		sub.Post("/forgot-password", accountHandler.ForgotPassword)
		sub.Post("/reset-password", accountHandler.ResetPassword)
		sub.Post("/resend-otp", accountHandler.ResendOTP)
		sub.With(appTokens.Middleware).Get("/me", accountHandler.Me)
		sub.With(appTokens.Middleware).Post("/change-password", accountHandler.ChangePassword)
	})

	// Workspace API — all behind the app's own JWT (the Flutter web app).
	taskHandler := handler.NewTaskHandler(queries)
	r.Group(func(api chi.Router) {
		api.Use(appTokens.Middleware)
		api.Mount("/api/v1/tasks", taskHandler.Routes())
		api.Mount("/api/v1/projects", handler.NewProjectHandler(queries).Routes())
		api.Mount("/api/v1/dependencies", handler.NewDependencyHandler(queries).Routes())
		api.Mount("/api/v1/milestones", handler.NewMilestoneHandler(queries).Routes())
		api.Mount("/api/v1/notifications", handler.NewNotificationHandler(queries).Routes())
		api.Get("/api/v1/team", handler.NewTeamHandler(queries).List)
		api.Post("/api/v1/baseline", taskHandler.SetBaseline)
		api.Patch("/api/v1/profile", accountHandler.UpdateProfile)
	})

	// Protected routes — require a valid Keycloak token.
	vkHandler := handler.NewVikunjaHandler(vk, vkSessions)
	if verifier != nil {
		r.With(verifier.Middleware).Get("/api/v1/me", handler.Me)
		r.Route("/api/v1/vikunja", func(sub chi.Router) {
			sub.Use(verifier.Middleware)
			sub.Post("/session", vkHandler.EstablishSession)
			sub.Get("/projects", vkHandler.ListProjects)
			sub.Handle("/proxy/*", vkHandler.Proxy())
		})
	} else {
		unavailable := func(w http.ResponseWriter, _ *http.Request) {
			http.Error(w, "auth not configured", http.StatusServiceUnavailable)
		}
		r.Get("/api/v1/me", unavailable)
		r.Mount("/api/v1/vikunja", http.HandlerFunc(unavailable))
	}

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("revahms backend listening on :%s", cfg.Port)
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
