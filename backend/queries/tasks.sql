-- name: ListTasks :many
SELECT t.*,
       p.name      AS project_name,
       u.full_name AS assignee_name,
       COALESCE(st.total, 0)::int AS subtask_count,
       COALESCE(st.done, 0)::int  AS subtask_done_count,
       COALESCE(a.ids, ARRAY[]::bigint[])::bigint[] AS assignee_ids,
       COALESCE(a.names, ARRAY[]::text[])::text[]   AS assignee_names
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
LEFT JOIN (
    SELECT ta.task_id,
           array_agg(ta.user_id ORDER BY au.full_name) AS ids,
           array_agg(au.full_name ORDER BY au.full_name) AS names
    FROM task_assignees ta
    JOIN users au ON au.id = ta.user_id
    GROUP BY ta.task_id
) a ON a.task_id = t.id
WHERE t.parent_id IS NULL
ORDER BY t.created_at DESC;

-- name: ListTaskAssignees :many
SELECT ta.user_id, u.full_name
FROM task_assignees ta
JOIN users u ON u.id = ta.user_id
WHERE ta.task_id = $1
ORDER BY u.full_name;

-- name: ClearTaskAssignees :exec
DELETE FROM task_assignees WHERE task_id = $1;

-- name: AddTaskAssignee :exec
INSERT INTO task_assignees (task_id, user_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

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
    reminder_sent = FALSE,
    updated_at = now()
WHERE id = $1;

-- name: DueReminders :many
SELECT id, title, assignee_id, due_date FROM tasks
WHERE NOT done
  AND assignee_id IS NOT NULL
  AND due_date IS NOT NULL
  AND due_date <= now() + INTERVAL '24 hours'
  AND NOT reminder_sent;

-- name: MarkReminded :exec
UPDATE tasks SET reminder_sent = TRUE WHERE id = $1;

-- name: SetBaseline :exec
UPDATE tasks
SET baseline_start = start_date,
    baseline_due   = due_date,
    updated_at     = now();

-- name: CreateTask :one
INSERT INTO tasks (title, description, project_id, assignee_id, start_date, due_date, status, parent_id, recurrence, priority, tags, estimate_minutes)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
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
    priority    = $10,
    tags        = $11,
    estimate_minutes = $12,
    done        = ($8 = 'done'),
    reminder_sent = FALSE,
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
    reminder_sent = CASE WHEN $2 THEN reminder_sent ELSE FALSE END,
    updated_at = now()
WHERE id = $1
RETURNING *;

-- name: DeleteTask :exec
DELETE FROM tasks
WHERE id = $1;

-- name: BulkSetTaskDone :exec
UPDATE tasks
SET done = sqlc.arg(done),
    status = CASE WHEN sqlc.arg(done) THEN 'done' ELSE 'todo' END,
    reminder_sent = CASE WHEN sqlc.arg(done) THEN reminder_sent ELSE FALSE END,
    updated_at = now()
WHERE id = ANY(sqlc.arg(ids)::bigint[]);

-- name: BulkSetTaskStatus :exec
UPDATE tasks
SET status = sqlc.arg(status),
    done   = (sqlc.arg(status) = 'done'),
    updated_at = now()
WHERE id = ANY(sqlc.arg(ids)::bigint[]);

-- name: BulkSetTaskPriority :exec
UPDATE tasks
SET priority = sqlc.arg(priority),
    updated_at = now()
WHERE id = ANY(sqlc.arg(ids)::bigint[]);

-- name: BulkSetTaskAssignee :exec
UPDATE tasks
SET assignee_id = sqlc.narg(assignee),
    updated_at = now()
WHERE id = ANY(sqlc.arg(ids)::bigint[]);

-- name: BulkDeleteTasks :exec
DELETE FROM tasks
WHERE id = ANY(sqlc.arg(ids)::bigint[]);
