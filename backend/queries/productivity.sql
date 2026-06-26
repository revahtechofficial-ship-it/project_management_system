-- name: ListFavorites :many
SELECT id, kind, item_id, label, route, created_at
FROM favorites
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: AddFavorite :exec
INSERT INTO favorites (user_id, kind, item_id, label, route)
VALUES (sqlc.arg(user_id), sqlc.arg(kind), sqlc.arg(item_id),
        sqlc.arg(label), sqlc.arg(route))
ON CONFLICT (user_id, kind, item_id)
DO UPDATE SET label = sqlc.arg(label), route = sqlc.arg(route);

-- name: RemoveFavorite :exec
DELETE FROM favorites
WHERE user_id = sqlc.arg(user_id) AND kind = sqlc.arg(kind)
  AND item_id = sqlc.arg(item_id);

-- name: ListSavedFilters :many
SELECT id, name, config, created_at
FROM saved_filters
WHERE user_id = $1
ORDER BY name;

-- name: CreateSavedFilter :one
INSERT INTO saved_filters (user_id, name, config)
VALUES (sqlc.arg(user_id), sqlc.arg(name), sqlc.arg(config))
RETURNING id, name, config, created_at;

-- name: DeleteSavedFilter :exec
DELETE FROM saved_filters
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id);

-- name: ListReminders :many
SELECT r.id, r.task_id, r.note, r.remind_at, r.sent, r.created_at,
       COALESCE(t.title, '')::text AS task_title
FROM reminders r
LEFT JOIN tasks t ON t.id = r.task_id
WHERE r.user_id = $1
ORDER BY r.remind_at;

-- name: CreateReminder :one
INSERT INTO reminders (user_id, task_id, note, remind_at)
VALUES (sqlc.arg(user_id), sqlc.narg(task_id), sqlc.arg(note),
        sqlc.arg(remind_at))
RETURNING id, task_id, note, remind_at, sent, created_at;

-- name: DeleteReminder :exec
DELETE FROM reminders
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id);

-- name: DueUserReminders :many
SELECT r.id, r.user_id, r.task_id, r.note,
       COALESCE(t.title, '')::text AS task_title
FROM reminders r
LEFT JOIN tasks t ON t.id = r.task_id
WHERE NOT r.sent AND r.remind_at <= now();

-- name: MarkReminderSent :exec
UPDATE reminders SET sent = TRUE WHERE id = $1;
