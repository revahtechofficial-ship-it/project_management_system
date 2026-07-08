-- name: ListSavedReports :many
SELECT * FROM saved_reports ORDER BY name, id;

-- name: CreateSavedReport :one
INSERT INTO saved_reports (name, config, created_by)
VALUES (sqlc.arg(name), sqlc.arg(config), sqlc.arg(created_by))
RETURNING *;

-- name: UpdateSavedReport :one
UPDATE saved_reports
SET name = sqlc.arg(name), config = sqlc.arg(config)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: DeleteSavedReport :exec
DELETE FROM saved_reports WHERE id = $1;
