-- name: ListUnreadNotificationsDigest :many
SELECT id, type, title, body, link, created_at
FROM notifications
WHERE user_id = $1 AND read = FALSE
ORDER BY created_at DESC
LIMIT 20;

-- name: ListMyDueTasks :many
SELECT DISTINCT t.id, t.title, t.status, t.done, t.due_date
FROM tasks t
LEFT JOIN task_assignees ta ON ta.task_id = t.id
WHERE t.due_date IS NOT NULL AND t.done = FALSE
  AND (ta.user_id = sqlc.arg(user_id) OR t.assignee_id = sqlc.arg(user_id))
ORDER BY t.due_date;
