-- name: ListTimeEntries :many
SELECT te.id, te.user_id, te.task_id, te.minutes, te.started_at, te.ended_at,
       te.description, te.billable, te.created_at,
       COALESCE(t.title, '')::text AS task_title,
       COALESCE(u.full_name, '')::text AS user_name
FROM time_entries te
LEFT JOIN tasks t ON t.id = te.task_id
LEFT JOIN users u ON u.id = te.user_id
WHERE te.user_id = sqlc.arg(user_id)
  AND te.started_at >= sqlc.arg(from_ts)
  AND te.started_at < sqlc.arg(to_ts)
ORDER BY te.started_at DESC;

-- name: ListAllTimeEntries :many
SELECT te.id, te.user_id, te.task_id, te.minutes, te.started_at, te.ended_at,
       te.description, te.billable, te.created_at,
       COALESCE(t.title, '')::text AS task_title,
       COALESCE(u.full_name, '')::text AS user_name
FROM time_entries te
LEFT JOIN tasks t ON t.id = te.task_id
LEFT JOIN users u ON u.id = te.user_id
WHERE te.started_at >= sqlc.arg(from_ts)
  AND te.started_at < sqlc.arg(to_ts)
  AND te.ended_at IS NOT NULL
ORDER BY te.started_at DESC;

-- name: GetTimeEntry :one
SELECT te.id, te.user_id, te.task_id, te.minutes, te.started_at, te.ended_at,
       te.description, te.billable, te.created_at,
       COALESCE(t.title, '')::text AS task_title,
       COALESCE(u.full_name, '')::text AS user_name
FROM time_entries te
LEFT JOIN tasks t ON t.id = te.task_id
LEFT JOIN users u ON u.id = te.user_id
WHERE te.id = $1;

-- name: GetActiveTimer :one
SELECT te.id, te.user_id, te.task_id, te.minutes, te.started_at, te.ended_at,
       te.description, te.billable, te.created_at,
       COALESCE(t.title, '')::text AS task_title,
       COALESCE(u.full_name, '')::text AS user_name
FROM time_entries te
LEFT JOIN tasks t ON t.id = te.task_id
LEFT JOIN users u ON u.id = te.user_id
WHERE te.user_id = $1 AND te.ended_at IS NULL
ORDER BY te.started_at DESC
LIMIT 1;

-- name: StartTimer :one
INSERT INTO time_entries (user_id, task_id, description, billable)
VALUES (sqlc.arg(user_id), sqlc.narg(task_id), sqlc.arg(description),
        sqlc.arg(billable))
RETURNING id;

-- name: StopTimer :one
UPDATE time_entries
SET ended_at = now(),
    minutes = GREATEST(
        1, ROUND(EXTRACT(EPOCH FROM (now() - started_at)) / 60.0)::int)
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id) AND ended_at IS NULL
RETURNING id;

-- name: CreateTimeEntry :one
INSERT INTO time_entries (user_id, task_id, minutes, started_at, ended_at,
                          description, billable)
VALUES (sqlc.arg(user_id), sqlc.narg(task_id), sqlc.arg(minutes),
        sqlc.arg(started_at), sqlc.arg(started_at), sqlc.arg(description),
        sqlc.arg(billable))
RETURNING id;

-- name: UpdateTimeEntry :exec
UPDATE time_entries
SET task_id = sqlc.narg(task_id), minutes = sqlc.arg(minutes),
    started_at = sqlc.arg(started_at), description = sqlc.arg(description),
    billable = sqlc.arg(billable)
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id);

-- name: DeleteTimeEntry :exec
DELETE FROM time_entries WHERE id = $1 AND user_id = $2;
