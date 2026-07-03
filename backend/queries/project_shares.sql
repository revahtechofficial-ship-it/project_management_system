-- name: GetProjectShareToken :one
SELECT token FROM project_shares WHERE project_id = $1;

-- name: CreateProjectShare :one
INSERT INTO project_shares (token, project_id, created_by)
VALUES (sqlc.arg(token), sqlc.arg(project_id), sqlc.arg(created_by))
RETURNING token;

-- name: RevokeProjectShare :exec
DELETE FROM project_shares WHERE project_id = $1;

-- name: GetSharedProject :one
SELECT p.id, p.name, p.description, p.status, p.due_date
FROM project_shares s
JOIN projects p ON p.id = s.project_id
WHERE s.token = $1;

-- name: ListSharedProjectTasks :many
SELECT t.id, t.title, t.done, t.status, t.due_date
FROM project_shares s
JOIN tasks t ON t.project_id = s.project_id
WHERE s.token = $1 AND t.parent_id IS NULL
ORDER BY t.done, t.created_at;
