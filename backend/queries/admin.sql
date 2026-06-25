-- name: CreateAuditLog :exec
INSERT INTO audit_log (actor_id, actor_name, action, target, detail)
VALUES (sqlc.narg(actor_id), sqlc.arg(actor_name), sqlc.arg(action),
        sqlc.arg(target), sqlc.arg(detail));

-- name: ListAuditLog :many
SELECT id, actor_id, actor_name, action, target, detail, created_at
FROM audit_log
ORDER BY created_at DESC
LIMIT 300;

-- name: ListAdminMembers :many
SELECT id, email, full_name, role, avatar, is_active, two_factor_enabled,
       created_at
FROM users
ORDER BY created_at ASC;

-- name: SetUserActive :one
UPDATE users SET is_active = sqlc.arg(is_active), updated_at = now()
WHERE id = sqlc.arg(id)
RETURNING id, email, full_name, role, is_active;

-- name: SetUserTwoFactor :exec
UPDATE users SET two_factor_enabled = sqlc.arg(two_factor_enabled),
       updated_at = now()
WHERE id = sqlc.arg(id);

-- name: GetWorkspaceSettings :one
SELECT id, name, allowed_domains, require_2fa, session_hours, updated_at
FROM workspace_settings WHERE id = 1;

-- name: UpdateWorkspaceSettings :exec
UPDATE workspace_settings
SET name = sqlc.arg(name), allowed_domains = sqlc.arg(allowed_domains),
    require_2fa = sqlc.arg(require_2fa), session_hours = sqlc.arg(session_hours),
    updated_at = now()
WHERE id = 1;
