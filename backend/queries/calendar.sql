-- name: GetUserCalendarToken :one
SELECT COALESCE(calendar_token, '')::text FROM users WHERE id = $1;

-- name: SetUserCalendarToken :exec
UPDATE users SET calendar_token = sqlc.arg(token) WHERE id = sqlc.arg(id);

-- name: ClearUserCalendarToken :exec
UPDATE users SET calendar_token = NULL WHERE id = $1;

-- name: GetUserByCalendarToken :one
SELECT id, COALESCE(full_name, '')::text AS full_name
FROM users WHERE calendar_token = $1;

-- name: ListCalendarTasks :many
SELECT DISTINCT t.id, t.title, t.description, t.status, t.due_date
FROM tasks t
LEFT JOIN task_assignees ta ON ta.task_id = t.id
WHERE t.due_date IS NOT NULL
  AND (ta.user_id = sqlc.arg(user_id) OR t.assignee_id = sqlc.arg(user_id))
ORDER BY t.due_date;
