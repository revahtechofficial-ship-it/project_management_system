-- name: AddWatcher :exec
INSERT INTO task_watchers (task_id, user_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: RemoveWatcher :exec
DELETE FROM task_watchers WHERE task_id = $1 AND user_id = $2;

-- name: IsWatching :one
SELECT EXISTS (
    SELECT 1 FROM task_watchers WHERE task_id = $1 AND user_id = $2
);

-- name: CountWatchers :one
SELECT COUNT(*)::int FROM task_watchers WHERE task_id = $1;

-- name: WatcherIDs :many
SELECT user_id FROM task_watchers WHERE task_id = $1;

-- name: WatchedTaskIDs :many
SELECT task_id FROM task_watchers WHERE user_id = $1
ORDER BY created_at DESC;
