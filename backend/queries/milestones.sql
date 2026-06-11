-- name: ListMilestones :many
SELECT * FROM milestones
ORDER BY due_date ASC;

-- name: CreateMilestone :one
INSERT INTO milestones (project_id, name, due_date)
VALUES ($1, $2, $3)
RETURNING *;

-- name: UpdateMilestone :one
UPDATE milestones
SET name     = $2,
    due_date = $3,
    done     = $4
WHERE id = $1
RETURNING *;

-- name: DeleteMilestone :exec
DELETE FROM milestones
WHERE id = $1;
