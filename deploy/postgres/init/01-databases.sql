-- Runs ONCE, on first initialization of an empty Postgres data volume, as the
-- postgres superuser. Creates a database + login role for each app that shares
-- this Postgres instance.
--
-- DEV PASSWORDS BELOW. For production, change them here AND in the consumers:
--   - Vikunja:     VIKUNJA_DATABASE_PASSWORD in docker-compose.yml
--   - Go backend:  DATABASE_URL in backend/.env (and the `backend` service in compose)

-- Revah Management System Go backend (BFF) ----------------------------------------------------
CREATE ROLE revahms WITH LOGIN PASSWORD 'revahms';
CREATE DATABASE revahms OWNER revahms;

-- Vikunja task engine -------------------------------------------------------
CREATE ROLE vikunja WITH LOGIN PASSWORD 'vikunja';
CREATE DATABASE vikunja OWNER vikunja;
