-- name: ListStatuses :many
SELECT * FROM task_statuses ORDER BY position, id;

-- name: GetStatus :one
SELECT * FROM task_statuses WHERE id = $1;

-- name: StatusKeyExists :one
SELECT EXISTS (SELECT 1 FROM task_statuses WHERE key = $1);

-- name: MaxStatusPosition :one
SELECT COALESCE(MAX(position), -1)::int FROM task_statuses;

-- name: CreateStatus :one
INSERT INTO task_statuses (key, label, color, position)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: UpdateStatus :one
UPDATE task_statuses
SET label = $2, color = $3, position = $4
WHERE id = $1
RETURNING *;

-- name: SetStatusPosition :exec
UPDATE task_statuses SET position = $2 WHERE id = $1;

-- name: DeleteStatus :exec
DELETE FROM task_statuses WHERE id = $1 AND NOT protected;

-- name: CountTasksWithStatus :one
SELECT COUNT(*) FROM tasks WHERE status = $1;
