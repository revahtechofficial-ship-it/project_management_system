-- name: CreateAPIKey :one
INSERT INTO api_keys (user_id, name, token_hash, prefix)
VALUES (sqlc.arg(user_id), sqlc.arg(name), sqlc.arg(token_hash),
        sqlc.arg(prefix))
RETURNING id, created_at;

-- name: ListAPIKeys :many
SELECT id, name, prefix, last_used_at, created_at
FROM api_keys
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: DeleteAPIKey :exec
DELETE FROM api_keys WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id);

-- name: LookupAPIKey :one
SELECT k.id, k.user_id, u.email, u.full_name, u.role
FROM api_keys k
JOIN users u ON u.id = k.user_id
WHERE k.token_hash = $1;

-- name: TouchAPIKey :exec
UPDATE api_keys SET last_used_at = now() WHERE id = $1;

-- name: CreateWebhook :one
INSERT INTO webhooks (url, secret, events, active, provider, created_by)
VALUES (sqlc.arg(url), sqlc.arg(secret), sqlc.arg(events), sqlc.arg(active),
        sqlc.arg(provider), sqlc.narg(created_by))
RETURNING *;

-- name: ListWebhooks :many
SELECT * FROM webhooks ORDER BY created_at DESC;

-- name: ListActiveWebhooks :many
SELECT * FROM webhooks WHERE active = true;

-- name: GetWebhook :one
SELECT * FROM webhooks WHERE id = $1;

-- name: UpdateWebhook :exec
UPDATE webhooks
SET url = sqlc.arg(url), events = sqlc.arg(events), active = sqlc.arg(active)
WHERE id = sqlc.arg(id);

-- name: DeleteWebhook :exec
DELETE FROM webhooks WHERE id = $1;

-- name: ListIntegrations :many
SELECT provider, connected, config, updated_at FROM integrations;

-- name: GetIntegration :one
SELECT provider, connected, config, updated_at FROM integrations
WHERE provider = $1;

-- name: ListConnectedByProvider :many
SELECT provider, config FROM integrations
WHERE connected = true AND provider = ANY(sqlc.arg(providers)::text[]);

-- name: UpsertIntegration :exec
INSERT INTO integrations (provider, connected, config, updated_by, updated_at)
VALUES (sqlc.arg(provider), sqlc.arg(connected), sqlc.arg(config),
        sqlc.narg(updated_by), now())
ON CONFLICT (provider) DO UPDATE
SET connected = sqlc.arg(connected), config = sqlc.arg(config),
    updated_by = sqlc.narg(updated_by), updated_at = now();

-- name: DeleteIntegration :exec
DELETE FROM integrations WHERE provider = $1;
