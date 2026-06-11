-- name: ListTasks :many
SELECT t.*,
       p.name      AS project_name,
       u.full_name AS assignee_name,
       COALESCE(st.total, 0)::int AS subtask_count,
       COALESCE(st.done, 0)::int  AS subtask_done_count
FROM tasks t
LEFT JOIN projects p ON p.id = t.project_id
LEFT JOIN users u ON u.id = t.assignee_id
LEFT JOIN (
    SELECT parent_id,
           COUNT(*)                     AS total,
           COUNT(*) FILTER (WHERE done) AS done
    FROM tasks
    WHERE parent_id IS NOT NULL
    GROUP BY parent_id
) st ON st.parent_id = t.id
WHERE t.parent_id IS NULL
ORDER BY t.created_at DESC;

-- name: ListSubtasks :many
SELECT * FROM tasks
WHERE parent_id = $1
ORDER BY created_at ASC;

-- name: GetTask :one
SELECT * FROM tasks
WHERE id = $1;

-- name: ListTasksRaw :many
SELECT * FROM tasks;

-- name: SetTaskDates :exec
UPDATE tasks
SET start_date = $2,
    due_date   = $3,
    updated_at = now()
WHERE id = $1;

-- name: SetBaseline :exec
UPDATE tasks
SET baseline_start = start_date,
    baseline_due   = due_date,
    updated_at     = now();

-- name: CreateTask :one
INSERT INTO tasks (title, description, project_id, assignee_id, start_date, due_date, status, parent_id, recurrence)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING *;

-- name: UpdateTask :one
UPDATE tasks
SET title       = $2,
    description = $3,
    project_id  = $4,
    assignee_id = $5,
    start_date  = $6,
    due_date    = $7,
    status      = $8,
    recurrence  = $9,
    done        = ($8 = 'done'),
    updated_at  = now()
WHERE id = $1
RETURNING *;

-- name: SetTaskStatus :one
UPDATE tasks
SET status = $2,
    done   = ($2 = 'done'),
    updated_at = now()
WHERE id = $1
RETURNING *;

-- name: SetTaskDone :one
UPDATE tasks
SET done = $2,
    status = CASE WHEN $2 THEN 'done' ELSE 'todo' END,
    updated_at = now()
WHERE id = $1
RETURNING *;

-- name: DeleteTask :exec
DELETE FROM tasks
WHERE id = $1;
