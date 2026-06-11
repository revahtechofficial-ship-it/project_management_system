-- name: ListNotifications :many
SELECT * FROM notifications
ORDER BY created_at DESC
LIMIT 50;

-- name: CountUnreadNotifications :one
SELECT COUNT(*) FROM notifications
WHERE read = FALSE;

-- name: CreateNotification :one
INSERT INTO notifications (type, title, body)
VALUES ($1, $2, $3)
RETURNING *;

-- name: MarkNotificationRead :exec
UPDATE notifications
SET read = TRUE
WHERE id = $1;

-- name: MarkAllNotificationsRead :exec
UPDATE notifications
SET read = TRUE
WHERE read = FALSE;
