-- name: ListSprints :many
SELECT s.*,
       COALESCE(t.task_count, 0)::int   AS task_count,
       COALESCE(t.done_count, 0)::int   AS done_count,
       COALESCE(t.total_points, 0)::int AS total_points,
       COALESCE(t.done_points, 0)::int  AS done_points
FROM sprints s
LEFT JOIN (
    SELECT sprint_id,
           COUNT(*)                          AS task_count,
           COUNT(*) FILTER (WHERE done)      AS done_count,
           SUM(points)                       AS total_points,
           SUM(points) FILTER (WHERE done)   AS done_points
    FROM tasks
    WHERE sprint_id IS NOT NULL
    GROUP BY sprint_id
) t ON t.sprint_id = s.id
ORDER BY s.created_at DESC;

-- name: GetSprint :one
SELECT * FROM sprints WHERE id = $1;

-- name: CreateSprint :one
INSERT INTO sprints (name, goal, status, start_date, end_date, created_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: UpdateSprint :one
UPDATE sprints
SET name = $2, goal = $3, start_date = $4, end_date = $5
WHERE id = $1
RETURNING *;

-- name: SetSprintStatus :one
UPDATE sprints SET status = $2 WHERE id = $1 RETURNING *;

-- name: DeleteSprint :exec
DELETE FROM sprints WHERE id = $1;

-- name: MoveSprintTasksToBacklog :exec
UPDATE tasks
SET sprint_id = NULL, updated_at = now()
WHERE sprint_id = $1 AND NOT done;
