-- name: ListNotifications :many
SELECT * FROM notifications
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT 50;

-- name: CountUnreadNotifications :one
SELECT COUNT(*) FROM notifications
WHERE user_id = $1 AND read = FALSE;

-- name: CreateNotification :one
INSERT INTO notifications (user_id, type, title, body, link)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: MarkNotificationRead :exec
UPDATE notifications
SET read = TRUE
WHERE id = $1 AND user_id = $2;

-- name: MarkAllNotificationsRead :exec
UPDATE notifications
SET read = TRUE
WHERE user_id = $1 AND read = FALSE;
