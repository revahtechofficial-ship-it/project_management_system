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
	"github.com/revah-tech/revahms/backend/internal/ai"
	"github.com/revah-tech/revahms/backend/internal/auth"
	"github.com/revah-tech/revahms/backend/internal/config"
	"github.com/revah-tech/revahms/backend/internal/db"
	"github.com/revah-tech/revahms/backend/internal/email"
	"github.com/revah-tech/revahms/backend/internal/handler"
	"github.com/revah-tech/revahms/backend/internal/reminder"
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

	// Background sweep: deliver in-app due-soon / overdue reminders to assignees.
	remCtx, remCancel := context.WithCancel(ctx)
	defer remCancel()
	reminder.Start(remCtx, queries, 30*time.Minute)

	// Custom email/password auth: users in Postgres, app-issued JWT, OTP email.
	mailer := email.NewSender(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPass, cfg.SMTPFrom, cfg.AppName, cfg.ResendAPIKey, cfg.ResendFrom)
	appTokens := account.NewTokens(cfg.JWTSecret)
	accountHandler := handler.NewAccountHandler(account.NewService(queries, appTokens, mailer))

	// Let in-app notifications also be delivered by email (opt-in per user).
	handler.SetNotifyMailer(mailer)

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
		sub.Post("/verify-login-otp", accountHandler.VerifyLoginOTP)
		sub.With(appTokens.Middleware).Get("/me", accountHandler.Me)
		sub.With(appTokens.Middleware).Post("/change-password", accountHandler.ChangePassword)
	})

	// Email-to-task webhook (public; guarded by INBOUND_EMAIL_SECRET). A mail
	// forwarder posts here to file a task; disabled when the secret is unset.
	r.Post("/api/v1/inbound/email",
		handler.NewInboundHandler(queries, cfg.InboundEmailSecret).Handle)

	// Public, read-only shared views reached via a share token (no auth).
	r.Get("/api/v1/public/projects/{token}",
		handler.NewPublicHandler(queries).SharedProject)

	// Git push webhook (public; the per-repo token is the credential). A
	// GitHub/GitLab push posts here to record commits against the repo.
	r.Post("/api/v1/git-webhook/{token}",
		handler.NewGitHandler(queries).Webhook)

	// Client portal (public; the per-client token is the credential). Shows a
	// client their projects and invoices read-only.
	r.Get("/api/v1/portal/{token}",
		handler.NewClientHandler(queries).Portal)

	// iCalendar feed (public; the per-user token is the credential). Calendar
	// apps subscribe to this URL to see a user's due tasks.
	r.Get("/api/v1/ics/{token}",
		handler.NewCalendarHandler(queries).Feed)

	// Workspace API — all behind the app's own JWT (the Flutter web app).
	if err := os.MkdirAll(cfg.UploadDir, 0o755); err != nil {
		log.Printf("WARNING: could not create upload dir %s: %v", cfg.UploadDir, err)
	}
	taskHandler := handler.NewTaskHandler(queries, cfg.UploadDir)
	avatarHandler := handler.NewAvatarHandler(queries, cfg.UploadDir)
	chatHub := handler.NewHub()
	chatHandler := handler.NewChatHandler(queries, cfg.UploadDir, chatHub, handler.LiveKitConfig{
		URL:       cfg.LiveKitURL,
		APIKey:    cfg.LiveKitAPIKey,
		APISecret: cfg.LiveKitAPISecret,
	})
	handler.SetSSOConfigured(cfg.OIDCIssuer != "")
	aiClient := ai.New(cfg.AnthropicAPIKey, cfg.AIModel)
	r.Group(func(api chi.Router) {
		api.Use(handler.APIKeyMiddleware(queries, appTokens.Middleware))
		api.Use(handler.GuestReadOnly)
		api.Mount("/api/v1/tasks", taskHandler.Routes())
		api.Mount("/api/v1/chat", chatHandler.Routes())
		api.Mount("/api/v1/projects", handler.NewProjectHandler(queries).Routes())
		api.Mount("/api/v1/dependencies", handler.NewDependencyHandler(queries).Routes())
		api.Mount("/api/v1/milestones", handler.NewMilestoneHandler(queries).Routes())
		api.Mount("/api/v1/notifications", handler.NewNotificationHandler(queries).Routes())
		api.Mount("/api/v1/digest", handler.NewDigestHandler(queries).Routes())
		api.Mount("/api/v1/metrics", handler.NewMetricsHandler(queries).Routes())
		api.Mount("/api/v1/reports", handler.NewReportHandler(queries).Routes())
		api.Mount("/api/v1/account", handler.NewAccountDataHandler(queries).Routes())
		api.Mount("/api/v1/holidays", handler.NewHolidayHandler(queries).Routes())
		api.Get("/api/v1/search", handler.NewSearchHandler(queries).Search)
		api.Get("/api/v1/link-preview", handler.LinkPreview)
		api.Mount("/api/v1/custom-fields", handler.NewCustomFieldHandler(queries).Routes())
		api.Mount("/api/v1/statuses", handler.NewStatusHandler(queries).Routes())
		api.Mount("/api/v1/task-templates", handler.NewTaskTemplateHandler(queries).Routes())
		api.Mount("/api/v1/project-templates", handler.NewProjectTemplateHandler(queries).Routes())
		api.Mount("/api/v1/checklist-templates", handler.NewChecklistTemplateHandler(queries).Routes())
		api.Mount("/api/v1/sprints", handler.NewSprintHandler(queries).Routes())
		api.Mount("/api/v1/releases", handler.NewReleaseHandler(queries).Routes())
		api.Mount("/api/v1/spaces", handler.NewSpaceHandler(queries).Routes())
		api.Mount("/api/v1/pages", handler.NewPageHandler(queries, chatHub).Routes())
		api.Mount("/api/v1/dashboards", handler.NewDashboardHandler(queries).Routes())
		api.Mount("/api/v1/time-entries", handler.NewTimeHandler(queries).Routes())
		api.Mount("/api/v1/timesheets", handler.NewTimesheetHandler(queries).Routes())
		api.Mount("/api/v1/one-on-ones", handler.NewOneOnOneHandler(queries).Routes())
		api.Mount("/api/v1/leave", handler.NewLeaveHandler(queries).Routes())
		api.Mount("/api/v1/approvals", handler.NewApprovalHandler(queries).Routes())
		api.Mount("/api/v1/assets", handler.NewAssetHandler(queries).Routes())
		api.Mount("/api/v1/expenses", handler.NewExpenseHandler(queries).Routes())
		api.Mount("/api/v1/budgets", handler.NewBudgetHandler(queries).Routes())
		api.Mount("/api/v1/incidents", handler.NewIncidentHandler(queries).Routes())
		api.Mount("/api/v1/git", handler.NewGitHandler(queries).Routes())
		api.Mount("/api/v1/invoices", handler.NewInvoiceHandler(queries).Routes())
		api.Mount("/api/v1/clients", handler.NewClientHandler(queries).Routes())
		api.Mount("/api/v1/calendar", handler.NewCalendarHandler(queries).Routes())
		api.Mount("/api/v1/objectives", handler.NewObjectiveHandler(queries).Routes())
		api.Mount("/api/v1/automations", handler.NewAutomationHandler(queries).Routes())
		api.Mount("/api/v1/resources", handler.NewResourceHandler(queries).Routes())
		api.Get("/api/v1/activity", handler.NewActivityHandler(queries).List)
		api.Mount("/api/v1/integrations", handler.NewIntegrationHandler(queries).Routes())
		api.Mount("/api/v1/admin", handler.NewAdminHandler(queries).Routes())
		api.Mount("/api/v1/ai", handler.NewAIHandler(queries, aiClient).Routes())
		api.Mount("/api/v1/calls", handler.NewCallModHandler(handler.LiveKitConfig{
			URL:       cfg.LiveKitURL,
			APIKey:    cfg.LiveKitAPIKey,
			APISecret: cfg.LiveKitAPISecret,
		}).Routes())
		productivity := handler.NewProductivityHandler(queries)
		api.Mount("/api/v1/favorites", productivity.FavoriteRoutes())
		api.Mount("/api/v1/saved-filters", productivity.FilterRoutes())
		api.Mount("/api/v1/reminders", productivity.ReminderRoutes())
		api.Patch("/api/v1/security/two-factor", accountHandler.SetTwoFactor)
		api.Patch("/api/v1/settings/email-notifications", accountHandler.SetEmailNotifications)
		teamHandler := handler.NewTeamHandler(queries)
		api.Get("/api/v1/team", teamHandler.List)
		api.Patch("/api/v1/team/{id}/role", teamHandler.SetRole)
		api.Mount("/api/v1/skills", handler.NewSkillHandler(queries).Routes())
		api.Post("/api/v1/baseline", taskHandler.SetBaseline)
		api.Delete("/api/v1/attachments/{id}", taskHandler.DeleteAttachment)
		api.Patch("/api/v1/profile", accountHandler.UpdateProfile)
		api.Post("/api/v1/profile/avatar", avatarHandler.Upload)
	})

	// Profile photos are public (random, content-addressed names).
	r.Get("/api/v1/avatars/{name}", avatarHandler.Serve)

	// File downloads accept the token via query param (browser navigation).
	r.With(appTokens.MiddlewareWithQuery).
		Get("/api/v1/attachments/{id}/download", taskHandler.DownloadAttachment)

	// Chat real-time socket + media downloads also take the token via query
	// param (the browser cannot set an Authorization header on either).
	r.With(appTokens.MiddlewareWithQuery).
		Get("/api/v1/chat/ws", chatHandler.WS)
	r.With(appTokens.MiddlewareWithQuery).
		Get("/api/v1/chat/messages/{id}/download", chatHandler.Download)

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
