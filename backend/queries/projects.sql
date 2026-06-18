-- name: ListProjects :many
SELECT p.*,
       COALESCE(c.total, 0)::int          AS total_tasks,
       COALESCE(c.done, 0)::int           AS done_tasks,
       COALESCE(m.member_names, '{}')::text[] AS member_names
FROM projects p
LEFT JOIN (
    SELECT project_id,
           COUNT(*)                    AS total,
           COUNT(*) FILTER (WHERE done) AS done
    FROM tasks
    WHERE project_id IS NOT NULL
    GROUP BY project_id
) c ON c.project_id = p.id
LEFT JOIN (
    SELECT t.project_id, array_agg(DISTINCT u.full_name) AS member_names
    FROM tasks t
    JOIN users u ON u.id = t.assignee_id
    WHERE t.project_id IS NOT NULL
    GROUP BY t.project_id
) m ON m.project_id = p.id
ORDER BY p.created_at DESC;

-- name: GetProject :one
SELECT * FROM projects
WHERE id = $1;

-- name: CreateProject :one
INSERT INTO projects (name, description, status, due_date, created_by, space_id, folder_id)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: UpdateProject :one
UPDATE projects
SET name        = $2,
    description = $3,
    status      = $4,
    due_date    = $5,
    space_id    = $6,
    folder_id   = $7,
    updated_at  = now()
WHERE id = $1
RETURNING *;

-- name: DeleteProject :exec
DELETE FROM projects
WHERE id = $1;
