-- name: CreateUser :one
INSERT INTO users (email, password_hash, full_name)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetUserByEmail :one
SELECT * FROM users
WHERE email = $1;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = $1;

-- name: UpdateUserName :one
UPDATE users
SET full_name = $2, updated_at = now()
WHERE id = $1
RETURNING *;

-- name: UpdateUserProfile :one
UPDATE users
SET full_name  = $2,
    phone      = $3,
    job_title  = $4,
    department = $5,
    location   = $6,
    bio        = $7,
    updated_at = now()
WHERE id = $1
RETURNING *;

-- name: SetUserAvatar :one
UPDATE users
SET avatar = $2, updated_at = now()
WHERE id = $1
RETURNING *;

-- name: SetUserStatus :exec
UPDATE users
SET status = $2, status_message = $3, updated_at = now()
WHERE id = $1;

-- name: SetLastSeen :exec
UPDATE users SET last_seen_at = now() WHERE id = $1;

-- name: ListUserStatuses :many
SELECT id, status, status_message, last_seen_at FROM users;

-- name: CountUsers :one
SELECT COUNT(*) FROM users;

-- name: SetUserRole :one
UPDATE users
SET role = $2, updated_at = now()
WHERE id = $1
RETURNING *;

-- name: EmailExists :one
SELECT EXISTS (SELECT 1 FROM users WHERE email = $1);

-- name: MarkEmailVerified :exec
UPDATE users
SET email_verified = TRUE, updated_at = now()
WHERE email = $1;

-- name: UpdatePassword :exec
UPDATE users
SET password_hash = $2, updated_at = now()
WHERE email = $1;
