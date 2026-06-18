-- name: ListTaskTemplates :many
SELECT * FROM task_templates ORDER BY name, id;

-- name: CreateTaskTemplate :one
INSERT INTO task_templates (
    name, title, description, status, priority, recurrence,
    estimate_minutes, tags, project_id, created_by
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING *;

-- name: DeleteTaskTemplate :exec
DELETE FROM task_templates WHERE id = $1;
