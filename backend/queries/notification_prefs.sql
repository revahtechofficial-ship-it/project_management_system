-- name: SetUserNotificationPrefs :exec
UPDATE users SET notification_prefs = sqlc.arg(prefs) WHERE id = sqlc.arg(id);
