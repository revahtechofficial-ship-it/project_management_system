-- name: ListCompletedTaskMetrics :many
SELECT id, title, created_at, start_date, completed_at
FROM tasks
WHERE done = true
  AND completed_at IS NOT NULL
  AND parent_id IS NULL
  AND completed_at >= sqlc.arg(since)
ORDER BY completed_at;
