# Revah Management System — Project Documentation

> Internal management system for **Revah Tech** (an IT company).
> Code slug: **`revahms`** · Repo: `github.com/revahtechofficial-ship-it/project_management_system`
> Last updated: 2026-06-10

> ⚠️ Naming note: this project was briefly mis-named "Nexax". **Nexax is a
> different, unrelated project.** Everything here is **Revah Management System**.
> (The local folder is still `management_system_nexax` — cosmetic only.)

---

## 1. What this is & why it exists

Revah Management System is a **self-hosted, single-sign-on collaborative
workspace** that a team uses to **plan projects, manage tasks, and (planned)
communicate** — all under one login, on infrastructure the company controls.

**Aims**
1. **Sovereign & self-hosted** — own all data on your own server; no vendor
   lock-in, no per-seat SaaS fees (a private alternative to Asana/Trello/Slack).
2. **Unify project management + team chat** in one custom app instead of
   juggling separate tools.
3. **One identity, one login (SSO)** across the whole workspace and Vikunja.
4. **Proven engines, custom UI** — Vikunja powers tasks under the hood; a custom
   Go backend + Flutter web app are the unified front door.

---

## 2. Architecture

```
   ┌─────────────────────────────────────────────────────────────┐
   │  Browser (Flutter Web app, served on :8090)                 │
   │  Riverpod · Dio · go_router                                 │
   └───────────────┬───────────────────────────┬─────────────────┘
       login (PKCE)│                            │ REST + Bearer (Keycloak JWT)
                   ▼                            ▼
        ┌──────────────────┐         ┌──────────────────────────┐
        │ Keycloak (:8088) │◄────────│  Go BFF (:8080, Chi)     │
        │ realm "revahms"  │ validate│  - validates Keycloak JWT │
        │ OIDC / SSO       │  (JWKS) │  - owns its own data      │
        └────────┬─────────┘         │  - bridges to Vikunja     │
                 │ OIDC               └──────┬──────────┬─────────┘
                 │                  own data │          │ per-user Vikunja token
                 ▼                           ▼          ▼
        ┌──────────────────┐      ┌──────────────┐  ┌──────────────────┐
        │ Vikunja (:3456)  │◄─────│ PostgreSQL   │  │ Vikunja API      │
        │ task engine      │ db   │ db "revahms" │  │ (projects/tasks) │
        │ db "vikunja"     │      └──────────────┘  └──────────────────┘
        └──────────────────┘
```

**Pattern:** the Go backend is a **Backend-for-Frontend (BFF)**. The Flutter app
never talks to Vikunja or Keycloak's token endpoint for data directly — it talks
to the BFF, which validates identity and aggregates/proxies downstream services.

**One PostgreSQL instance, two databases:** `revahms` (the BFF's own data) and
`vikunja` (Vikunja's data).

---

## 3. Technology stack (with versions)

### Frontend — Flutter Web
| Tool | Version | Role |
|---|---|---|
| Flutter / Dart | 3.44.0 / 3.12 | UI framework (web target) |
| flutter_riverpod | ^3.3.1 | state management & DI |
| dio | ^5.9.2 | HTTP client (BFF calls) |
| go_router | ^17.3.0 | declarative routing + auth gate |
| shared_preferences | ^2.5.5 | token/session storage (localStorage on web) |
| crypto | ^3.0.7 | PKCE `S256` challenge |
| url_launcher | ^6.3.2 | OIDC redirect navigation |
| logger | ^2.7.0 | logging (no `print`) |
| web_socket_channel | ^3.0.3 | realtime (stub, for future chat) |
| firebase_core | ^4.10.0 | initialized but **unused** (see §12) |
| cached_network_image / hugeicons | ^3.4.1 / ^1.1.7 | images/icons (available, unused) |
| spider (dev) | ^4.2.3 | type-safe asset codegen (`AppImages`) |
| flutter_lints (dev) | ^6.0.0 | lints |

- **Package name:** `revahms_web` · **Root widget:** `RevahApp`
- **Manual JSON serialization** (no `json_serializable`/`build_runner`) — required by `frontend/AGENTS.md`.

### Backend — Go (BFF)
| Tool | Version | Role |
|---|---|---|
| Go | 1.26.3 | language |
| go-chi/chi | v5.3.0 | HTTP router |
| go-chi/cors | v1.2.2 | CORS |
| jackc/pgx | v5.10.0 | PostgreSQL driver + pool |
| sqlc | (go tool) | type-safe SQL → Go codegen |
| pressly/goose | v3.27.1 | embedded DB migrations |
| coreos/go-oidc | v3.18.0 | Keycloak JWT verification |
| joho/godotenv | v1.5.1 | `.env` loading |

- **Module path:** `github.com/revah-tech/revahms/backend`

### Platform services (Docker)
| Service | Version | Role |
|---|---|---|
| PostgreSQL | 18 | database (BFF + Vikunja) |
| Vikunja | 2.3.0 | upstream task/project engine |
| Keycloak | 26 | OIDC identity provider / SSO |
| Docker Compose | — | local orchestration |

---

## 4. Current state (honest status)

**Foundation — ✅ done & verified**
- Full **SSO** (Keycloak) across app → BFF → Vikunja.
- **Go BFF** with its own Postgres DB, JWT validation, and the per-user Vikunja bridge.
- **Flutter web** app, strictly structured per `AGENTS.md`, builds/analyzes/tests clean.
- **Docker** stack (Postgres + Vikunja + Keycloak) with realm-as-code.

**Application UI — ⚠️ minimal (3 screens)**
- Login, Tasks (list + toggle done), Vikunja Projects (read-only list).

**Not yet built — ❌** dashboard, task/project CRUD UI, Kanban/Gantt/calendar,
chat, search, notifications, profile/settings, teams. (Full roadmap in §16.)

---

## 5. Features already built (detail)

### 5.1 Authentication & SSO (Keycloak) — built in 4 phases
- **Phase 1 — Keycloak + realm.** Realm `revahms` defined as code
  (`deploy/keycloak/import/revahms-realm.json`): public PKCE client
  `revahms-web`, confidential client `vikunja`, a test user. Issuer is
  `http://host.docker.internal:8088/realms/revahms` (host.docker.internal so the
  **browser and the containers see the same issuer**).
- **Phase 2 — BFF validates tokens.** `internal/auth` uses `go-oidc` to verify
  the Keycloak JWT (signature via JWKS, issuer, expiry). Protected routes reject
  missing/invalid/expired tokens (401).
- **Phase 3 — Flutter login.** `auth_service.dart` runs the **Authorization
  Code + PKCE** flow: builds the challenge, redirects to Keycloak, exchanges the
  code for tokens, stores them, and Dio attaches the bearer to BFF calls. Auth
  gate via go_router (`/login` when unauthenticated).
- **Phase 4 — per-user Vikunja bridge.** Vikunja issues *its own* token, so the
  app runs a **second, silent OIDC flow** for the `vikunja` client; the BFF
  swaps that code at Vikunja's `/auth/openid/keycloak/callback` for a **Vikunja
  JWT**, caches it per user (`vikunja.SessionStore`, keyed by Keycloak subject),
  and uses it for all `/vikunja/*` calls. One login → reaches Vikunja too.

### 5.2 Backend (BFF)
- **Own-data tasks API** (`/api/v1/tasks`) backed by the `revahms` Postgres DB
  via sqlc-generated, type-safe queries.
- **Embedded migrations** (goose) applied automatically at startup.
- **Vikunja BFF**: typed `/projects` + transparent `/proxy/*`, both per-user.
- Health check, structured middleware (request id, logging, recovery, timeout,
  CORS), graceful shutdown.

### 5.3 Frontend (app)
- **Login screen**, **Tasks screen** (list, mark done, username, logout, nav to
  Vikunja), **Vikunja Projects screen** (per-user projects via the bridge, with
  a "Connect Vikunja" fallback).
- Strict **feature-based architecture** (`core/ data/ providers/ features/`).

### 5.4 Infrastructure
- One-command Docker stack; one-time SQL creates the `revahms` + `vikunja`
  databases/roles; multi-stage backend Dockerfile (optional containerized BFF).

---

## 6. Repository structure

```
management_system_nexax/            (folder name — cosmetic)
├── docker-compose.yml              # Postgres + Vikunja + Keycloak (+ optional backend)
├── .env.example                    # compose secrets (copy to .env)
├── README.md / DOCUMENTATION.md
├── deploy/
│   ├── postgres/init/01-databases.sql   # creates revahms + vikunja DBs/roles
│   └── keycloak/import/revahms-realm.json # realm-as-code (clients + test user)
├── backend/                        # Go BFF
│   ├── Dockerfile
│   ├── cmd/server/main.go          # entrypoint: migrate, wire routes, serve
│   ├── internal/
│   │   ├── auth/auth.go            # OIDC verifier + middleware + claims
│   │   ├── config/config.go        # env config (DATABASE_URL, OIDC_ISSUER, …)
│   │   ├── db/                      # sqlc-GENERATED (db.go, models.go, tasks.sql.go)
│   │   ├── handler/                # tasks.go, vikunja.go, me.go, response.go
│   │   └── vikunja/                # client.go (API + Login), sessions.go (token cache)
│   ├── migrations/00001_init.sql   # goose (tasks table), embedded
│   ├── queries/tasks.sql           # sqlc query source
│   └── sqlc.yaml
└── frontend/                       # Flutter web (revahms_web)
    ├── AGENTS.md / CLAUDE.md        # binding frontend engineering standards
    ├── .agents/skills/             # 6 skill stubs referenced by AGENTS.md §11
    └── lib/
        ├── main.dart               # entry: Firebase init + runApp(RevahApp)
        ├── app.dart                # RevahApp: MaterialApp.router + Vikunja auto-handshake
        ├── firebase_options.dart   # generated (unused at runtime beyond init)
        ├── core/
        │   ├── constants/app_config.dart   # API/OIDC URLs, client id, redirect
        │   ├── constants/app_images.dart    # spider-generated AppImages
        │   ├── extensions/string_extensions.dart  # inCaps
        │   ├── routing/app_router.dart      # routes + auth-gate redirect
        │   ├── services/auth_service.dart   # the two OIDC/PKCE flows
        │   ├── services/logger.dart
        │   ├── services/realtime_service.dart # WebSocket stub (future chat)
        │   └── utils/api_exception.dart
        ├── data/
        │   ├── models/task.dart, vikunja_project.dart   # manual JSON
        │   └── repositories/tasks_repository.dart, vikunja_repository.dart
        ├── providers/
        │   ├── auth_provider.dart   # AuthController (AsyncNotifier) + AuthState
        │   └── dio_provider.dart    # Dio + bearer-attach interceptor
        └── features/
            ├── auth/auth_page.dart
            ├── tasks/tasks_page.dart + providers/
            └── vikunja/vikunja_projects_page.dart + providers/
```

---

## 7. API reference (BFF, `http://localhost:8080`)

| Method | Path | Auth | Body / Notes |
|---|---|---|---|
| GET | `/healthz` | — | liveness + DB ping |
| GET | `/api/v1/tasks` | open* | list tasks (own DB) |
| POST | `/api/v1/tasks` | open* | `{ "title", "description" }` |
| GET | `/api/v1/tasks/{id}` | open* | one task |
| PATCH | `/api/v1/tasks/{id}` | open* | `{ "done": true }` |
| DELETE | `/api/v1/tasks/{id}` | open* | — |
| GET | `/api/v1/me` | **Keycloak JWT** | the caller's OIDC claims |
| POST | `/api/v1/vikunja/session` | **Keycloak JWT** | `{ "code", "redirect_uri" }` → establishes the Vikunja bridge |
| GET | `/api/v1/vikunja/projects` | **Keycloak JWT** | user's Vikunja projects (428 if bridge not established) |
| ANY | `/api/v1/vikunja/proxy/*` | **Keycloak JWT** | passthrough → `{vikunja}/api/v1/*` with the user's Vikunja token |

\* The `tasks` demo routes are currently **not** behind the auth middleware — a
known item to lock down (see §17).

---

## 8. Data model

**`revahms.tasks`** (BFF-owned, Postgres):

| Column | Type | Notes |
|---|---|---|
| id | BIGSERIAL PK | |
| title | TEXT NOT NULL | |
| description | TEXT NOT NULL DEFAULT '' | |
| done | BOOLEAN NOT NULL DEFAULT false | |
| created_at | TIMESTAMPTZ DEFAULT now() | |
| updated_at | TIMESTAMPTZ DEFAULT now() | |

JSON is **snake_case** (`created_at`) to match Vikunja and the Dart models.

**Vikunja data** (projects, tasks, etc.) lives in the `vikunja` database and is
reached only through the BFF bridge — Revah MS does not own/duplicate it.

---

## 9. Environments, ports, URLs & credentials (local dev)

| Service | URL / Port | Credentials |
|---|---|---|
| Flutter web app | http://localhost:8090 | (login via SSO) |
| Go BFF | http://localhost:8080 | — |
| Vikunja | http://localhost:3456 | local user, or "Log in with Keycloak" |
| Keycloak admin | http://localhost:8088 | `admin` / `admin` |
| PostgreSQL (Docker) | localhost:**5433** | `revahms`/`revahms`, `vikunja`/`vikunja`, super `postgres`/`postgres` |
| SSO test user | (Keycloak realm `revahms`) | **`revah` / `revahms-dev`** |

- OIDC clients: **`revahms-web`** (public, PKCE, redirect `http://localhost:8090/*`)
  and **`vikunja`** (confidential, secret `vikunja-oidc-dev-secret`).
- Postgres host port is **5433** because the machine also runs a **native**
  PostgreSQL on 5432.

> All passwords/secrets above are **dev-only**. Change them (and
> `VIKUNJA_SERVICE_SECRET`) before any real deployment.

---

## 10. Build & run (local)

```sh
# 1) Platform services (Postgres + Vikunja + Keycloak)
cp .env.example .env          # set VIKUNJA_SERVICE_SECRET (openssl rand -hex 32)
docker compose up -d

# 2) Backend (BFF) — needs the stack up
cd backend
cp .env.example .env          # defaults already match the Docker services
go run ./cmd/server           # migrates, then serves :8080 (logs the OIDC issuer)

# 3) Frontend — MUST use --web-port=8090 (matches the realm redirect URI)
cd ../frontend
flutter run -d chrome --web-port=8090 --dart-define=API_BASE_URL=http://localhost:8080
```

**Login flow you'll see:** Login screen → Keycloak (`revah`/`revahms-dev`) → a
brief silent second redirect (the Vikunja bridge) → Tasks. The folder icon opens
Vikunja Projects fetched through the BFF.

---

## 11. Dev-environment notes (Windows + Docker Desktop)

These are real, machine-specific gotchas worth knowing:
- **Docker** required enabling the *Virtual Machine Platform* Windows feature
  (`wsl --install --no-distribution`) + reboot.
- A **native PostgreSQL 18** runs on 5432 → the Docker Postgres is published on
  **5433** (`backend/.env` uses `127.0.0.1:5433`).
- **npm** needed `NODE_OPTIONS=--use-system-ca` (persisted) to get past a
  corporate-CA TLS interception (for installing `firebase-tools`).
- PowerShell execution policy set to **RemoteSigned** (CurrentUser) so
  `firebase.ps1` runs.
- When scripting Docker from PowerShell, put docker on `PATH` rather than calling
  the full `"C:\Program Files\...\docker.exe"` path (a sandbox guard misreads it).

---

## 12. Firebase (status)

`firebase_core` is added and `Firebase.initializeApp(...)` runs at startup
(project `managementsystem-5dd61`), **but no Firebase service is used** — auth is
Keycloak/OIDC and data is the BFF. It exists only to satisfy `AGENTS.md §1`. It
can be removed, or later given a real job (e.g. FCM push). Firebase **web config
values are public by design**, so they're safe to keep in the repo.

---

## 13. Engineering standards

The frontend is governed by **`frontend/AGENTS.md`** (and `CLAUDE.md`, which just
imports it). Highlights the codebase follows:
- Feature-based layout (`core/ data/ providers/ features/`).
- **Riverpod only** for app state (no `provider`/`ChangeNotifier`/`setState`).
- **Manual JSON** serialization (no `json_serializable`).
- `go_router`, `logger`, private widget classes, 80-col lines, `///` docs.

---

## 14. Quality gates (all green)
- Backend: `go build ./...`, `go vet ./...` pass.
- Frontend: `flutter analyze` (no issues), `flutter test` (passing).
- Infra: realm discovery, databases, and Vikunja OIDC verified after each change.

---

## 15. The product — two pillars

| Pillar | Engine | Status |
|---|---|---|
| 📋 Project / Task management | Vikunja (via BFF) | most complete |
| 💬 Team chat | (to build; WebSocket stub exists) | not started |

…tied together by SSO, and (planned) a dashboard, global search, and notifications.

---

## 16. Roadmap (not yet built)

**Identity:** self-signup (Keycloak toggle), password reset/MFA (free via
Keycloak), profile/account page.

**Projects & Tasks:** full CRUD UI, task detail (due dates, priority, assignees,
labels), subtasks, comments, attachments, **Kanban**, **Gantt**, **calendar**,
filters/saved views, "My Tasks" dashboard.

**Chat:** channels, DMs, real-time messages, threads, mentions, file sharing,
search.

**Cross-cutting:** home dashboard, global search, notifications center, teams &
roles, activity feed, Vikunja→chat webhooks, dark mode, settings.

**Suggested next step:** Tasks/Projects CRUD UI + a navigation shell (sidebar),
then Kanban — turning the read-only demo into a real PM tool.

---

## 17. Known limitations / tech debt
- `/api/v1/tasks` is **not auth-protected** yet (demo); should sit behind the
  Keycloak middleware like `/vikunja/*`.
- Vikunja bridge cache is **in-memory** (lost on BFF restart → silent re-handshake)
  and has **no token refresh** yet.
- Keycloak access-token audience check is skipped (`SkipClientIDCheck`); add an
  audience mapper to tighten.
- Login involves **two redirects** (the second is silent) — acceptable but could
  be smoothed with a hidden iframe later.
- All dev secrets/passwords are placeholders — rotate before production.
- No CI yet; no production deployment/reverse-proxy/TLS config yet.
```
