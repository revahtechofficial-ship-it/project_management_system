-- name: ListTasks :many
SELECT * FROM tasks
ORDER BY created_at DESC;

-- name: GetTask :one
SELECT * FROM tasks
WHERE id = $1;

-- name: CreateTask :one
INSERT INTO tasks (title, description)
VALUES ($1, $2)
RETURNING *;

-- name: SetTaskDone :one
UPDATE tasks
SET done = $2,
    updated_at = now()
WHERE id = $1
RETURNING *;

-- name: DeleteTask :exec
DELETE FROM tasks
WHERE id = $1;
