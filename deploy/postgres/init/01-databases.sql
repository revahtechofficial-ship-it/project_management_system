-- Runs ONCE, on first initialization of an empty Postgres data volume, as the
-- postgres superuser. Creates a database + login role for each app that shares
-- this Postgres instance.
--
-- DEV PASSWORDS BELOW. For production, change them here AND in the consumers:
--   - Vikunja:     VIKUNJA_DATABASE_PASSWORD in docker-compose.yml
--   - Go backend:  DATABASE_URL in backend/.env (and the `backend` service in compose)

-- Nexax Go backend (BFF) ----------------------------------------------------
CREATE ROLE nexax WITH LOGIN PASSWORD 'nexax';
CREATE DATABASE nexax OWNER nexax;

-- Vikunja task engine -------------------------------------------------------
CREATE ROLE vikunja WITH LOGIN PASSWORD 'vikunja';
CREATE DATABASE vikunja OWNER vikunja;
