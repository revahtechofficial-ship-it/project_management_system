-- name: ListDependencies :many
SELECT * FROM task_dependencies
ORDER BY id;

-- name: CreateDependency :one
INSERT INTO task_dependencies (predecessor_id, successor_id, type)
VALUES ($1, $2, $3)
RETURNING *;

-- name: DeleteDependency :exec
DELETE FROM task_dependencies
WHERE id = $1;
