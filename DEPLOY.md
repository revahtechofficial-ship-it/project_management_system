# Deploying Revah Management System

Architecture: **Flutter web frontend** (static, on **GitHub Pages**) + **Go backend**
(`backend/`) and **PostgreSQL** on a managed host (**Render**). The frontend is
built with the backend's URL baked in, and the backend allows the frontend's
origin via CORS.

> HTTPS is required — the camera, microphone, screen-share, and location
> features only work on a secure origin. GitHub Pages and Render both give you
> HTTPS for free.

You'll need: this GitHub repo (done), a free **Render** account, your domain's
DNS, your **Gmail App Password** (already in your local `.env`), and optionally a
**Giphy API key** and a **LiveKit Cloud** project (for calls).

---

## 1. Deploy the backend (Render)

1. Go to <https://dashboard.render.com> → **New ▸ Blueprint** → select this repo.
   Render reads [`render.yaml`](render.yaml) and provisions **revahms-db**
   (Postgres) + **revahms-backend** (the Go service).
2. When prompted, fill the secret env vars (the `sync: false` ones):
   - `SMTP_USER` = `revah.tech.official@gmail.com`
   - `SMTP_PASS` = your Gmail App Password
   - `SMTP_FROM` = `revah.tech.official@gmail.com`
   - `CORS_ORIGIN` = leave blank for now (set it in step 4)
   - `LIVEKIT_*` = leave blank unless you set up calls (see step 6)
3. Deploy. Migrations run automatically on boot. When it's live, copy the URL,
   e.g. `https://revahms-backend.onrender.com`. Check `…/healthz` returns `ok`.

> Notes: the blueprint uses the **starter** web plan so uploads persist on a
> disk and the service doesn't sleep. The **free** plan has no disk (uploaded
> files are lost on each redeploy) and sleeps when idle. The **free Postgres**
> expires after ~30 days — upgrade for production.

## 2. Configure the frontend build (GitHub)

In the repo: **Settings ▸ Secrets and variables ▸ Actions**.

- **Variables** tab → New variable:
  - `API_BASE_URL` = your backend URL from step 1 (e.g. `https://revahms-backend.onrender.com`)
  - `CUSTOM_DOMAIN` = your frontend domain (e.g. `app.yourdomain.com`) — omit to use the github.io URL
  - `BASE_HREF` = `/` if using a custom domain. If you instead use the github.io
    project URL, set it to `/project_management_system/`.
- **Secrets** tab → New secret (optional):
  - `GIPHY_API_KEY` = your Giphy key (enables GIFs/stickers)

## 3. Turn on GitHub Pages

- **Settings ▸ Pages ▸ Build and deployment ▸ Source = "GitHub Actions"**.
- Run the deploy: **Actions ▸ "Deploy frontend to GitHub Pages" ▸ Run workflow**
  (or just push a change under `frontend/`). The
  [workflow](.github/workflows/deploy.yml) builds the web app with your
  `API_BASE_URL`/`GIPHY_API_KEY` and publishes it.
- The first run prints the live URL (e.g. `https://<you>.github.io/project_management_system/`).

## 4. Allow the frontend origin (CORS)

Back on Render → the backend service → **Environment** → set:

- `CORS_ORIGIN` = the frontend **origin** (scheme + host, no path):
  - custom domain → `https://app.yourdomain.com`
  - github.io → `https://<you>.github.io`

Save (the service redeploys). Now the browser app can call the API.

## 5. Point your domain

**Frontend (GitHub Pages):**
- Subdomain (`app.yourdomain.com`): add a DNS **CNAME** → `<you>.github.io`.
- Apex (`yourdomain.com`): add **A** records to GitHub Pages IPs
  `185.199.108.153`, `.109`, `.110`, `.111` (and AAAA for IPv6).
- In **Settings ▸ Pages**, the custom domain is taken from the `CUSTOM_DOMAIN`
  variable (written as a `CNAME` file by the workflow). Tick **Enforce HTTPS**
  once the certificate is issued.

**Backend (optional custom subdomain):** in Render → service → **Settings ▸
Custom Domains** → add `api.yourdomain.com`, then add a DNS **CNAME** →
`revahms-backend.onrender.com`. If you do this, update `API_BASE_URL` to
`https://api.yourdomain.com` and re-run the Pages workflow. (Otherwise the
`onrender.com` URL works fine.)

## 6. Calls (optional — LiveKit)

Self-hosting LiveKit on a managed PaaS is awkward (it needs UDP). Easiest:
1. Create a free project at <https://cloud.livekit.io>.
2. Copy the **WebSocket URL**, **API Key**, **API Secret**.
3. On Render set `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`.

Without these, everything works except voice/video calls.

---

## Updating after launch

- **Frontend**: push to `main` (changes under `frontend/`) → GitHub Actions
  rebuilds and redeploys Pages automatically.
- **Backend**: push to `main` → Render auto-deploys (`autoDeploy: true`) and runs
  any new migrations on boot.

## Going beyond a trial

- Move uploads to object storage (S3 / Cloudflare R2) so they survive without a
  disk and scale across instances.
- Upgrade the Postgres plan (the free one expires).
- Set a strong, private `JWT_SECRET` (Render generates one via `generateValue`).
