# Nexax — Unified Collaborative Workspace

A self-hosted workspace with a **Go** backend (acting as a **BFF**), a
**PostgreSQL** database, a **Flutter web** frontend, and **Vikunja** as the
upstream task-management engine.

## Architecture

```
  Flutter web (Riverpod + Dio)
        │  REST  (http://localhost:8080)
        ▼
  Go backend  ── BFF / aggregator ──┐
   (Chi)                            │ proxies + aggregates
     │ own data                     ▼
     ▼                         Vikunja API (:3456)
  PostgreSQL  ◄───────────────────  │  (own `vikunja` DB)
  (`nexax` DB)                       
```

The Go backend owns its own data (`nexax` DB) **and** calls Vikunja on the
user's behalf, forwarding the user's `Authorization` header. Both apps share one
PostgreSQL instance (separate databases).

## Stack

| Layer        | Choice                                   |
| ------------ | ---------------------------------------- |
| Frontend     | Flutter web + Riverpod + Dio + go_router |
| Backend (BFF)| Go + Chi router                          |
| DB access    | pgx + sqlc (type-safe, generated)        |
| Migrations   | goose (embedded, applied at startup)     |
| Task engine  | Vikunja 2.3.0 (upstream service)         |
| Database     | PostgreSQL 18                            |
| Local infra  | Docker Compose                           |

## Layout

```
management_system_nexax/
├── docker-compose.yml          # Postgres + Vikunja (+ optional backend profile)
├── .env.example                # compose secrets (copy to .env)
├── deploy/postgres/init/       # one-time SQL: creates nexax + vikunja DBs/roles
├── backend/                    # Go BFF
│   ├── Dockerfile
│   ├── cmd/server/             # main.go — entrypoint
│   ├── internal/
│   │   ├── config/             # env-based config
│   │   ├── db/                 # sqlc-GENERATED code (do not edit)
│   │   ├── handler/            # HTTP handlers (tasks + vikunja BFF)
│   │   └── vikunja/            # Vikunja API client
│   ├── migrations/             # goose .sql migrations (embedded)
│   ├── queries/                # sqlc query sources
│   └── sqlc.yaml
└── frontend/                   # Flutter web app (conventions in frontend/AGENTS.md)
    └── lib/
        ├── core/               # constants, extensions, routing, services
        ├── data/               # models (manual JSON), repositories
        ├── providers/          # global providers (dio_provider)
        ├── features/           # feature folders, e.g. tasks/
        ├── app.dart            # root MaterialApp + router
        └── main.dart
```

## Prerequisites

- Go 1.26+
- Flutter 3.44+ (Dart 3.12+)
- **Docker Desktop for Windows (WSL2 backend)** — for Postgres + Vikunja

> `sqlc` is wired as a Go tool dependency — no separate install needed.

## 1. Bring up Postgres + Vikunja (Docker)

```sh
cp .env.example .env
# Set a real VIKUNJA_SERVICE_SECRET in .env:  openssl rand -hex 32
docker compose up -d            # starts db + vikunja
```

- Vikunja UI/API: http://localhost:3456  (create your first user there)
- Postgres: localhost:5432 (databases `nexax` and `vikunja` are auto-created)

> The Vikunja docs' `mkdir files db && chown 1000 files db` step is **Linux-only**
> and **not** needed here — Compose creates the volumes for you.

## 2. Run the Go backend

```sh
cd backend
cp .env.example .env            # defaults already match the Docker Postgres + Vikunja
go tool sqlc generate           # only after editing queries/ or migrations/
go run ./cmd/server             # applies migrations, then serves on :8080
```

Health check: `GET http://localhost:8080/healthz`

> To run the backend in Docker too: `docker compose --profile app up -d --build`

### REST API

Backend-owned `tasks` demo (Postgres):

| Method | Path                 | Body                          |
| ------ | -------------------- | ----------------------------- |
| GET    | /api/v1/tasks        | —                             |
| POST   | /api/v1/tasks        | `{"title","description"}`     |
| GET    | /api/v1/tasks/{id}   | —                             |
| PATCH  | /api/v1/tasks/{id}   | `{"done": true}`              |
| DELETE | /api/v1/tasks/{id}   | —                             |

Vikunja BFF (forwards your `Authorization` header to Vikunja):

| Method | Path                          | Notes                                    |
| ------ | ----------------------------- | ---------------------------------------- |
| GET    | /api/v1/vikunja/projects      | Typed/aggregated list of Vikunja projects |
| ANY    | /api/v1/vikunja/proxy/*       | Passthrough → `{vikunja}/api/v1/*`        |

## 3. Run the frontend

```sh
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

## Security notes (dev defaults — change for production)

- DB role passwords (`nexax`, `vikunja`) are hardcoded in
  `deploy/postgres/init/01-databases.sql`. Change them there **and** in
  `docker-compose.yml` / `backend/.env`.
- Set a strong `VIKUNJA_SERVICE_SECRET`; never commit `.env`.
- The `/api/v1/vikunja/proxy/*` passthrough is a dev convenience — lock it down
  (or remove it) before production.

## Next steps

- [ ] OIDC/JWT auth (PKCE) — attach the bearer token in `dioProvider` (frontend)
      and validate/forward it in the backend. Vikunja supports OIDC; configure it
      under its admin settings.
- [ ] WebSocket handler on the backend (`/api/v1/ws`) + StreamProvider on the client
- [ ] Replace the `tasks` demo with real domain models, or aggregate Vikunja data
