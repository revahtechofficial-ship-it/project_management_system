-- name: ListProjectTemplates :many
SELECT * FROM project_templates ORDER BY name, id;

-- name: CreateProjectTemplate :one
INSERT INTO project_templates (name, project_name, description, status, created_by)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: DeleteProjectTemplate :exec
DELETE FROM project_templates WHERE id = $1;
