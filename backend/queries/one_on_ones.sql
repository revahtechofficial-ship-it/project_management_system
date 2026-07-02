-- name: CreateOneOnOne :one
INSERT INTO one_on_ones (manager_id, report_id, scheduled_at)
VALUES (sqlc.arg(manager_id), sqlc.arg(report_id), sqlc.arg(scheduled_at))
RETURNING *;

-- name: ListMyOneOnOnes :many
SELECT o.*,
       m.full_name AS manager_name,
       r.full_name AS report_name
FROM one_on_ones o
JOIN users m ON m.id = o.manager_id
JOIN users r ON r.id = o.report_id
WHERE o.manager_id = sqlc.arg(user_id) OR o.report_id = sqlc.arg(user_id)
ORDER BY o.scheduled_at DESC;

-- name: GetOneOnOne :one
SELECT o.*,
       m.full_name AS manager_name,
       r.full_name AS report_name
FROM one_on_ones o
JOIN users m ON m.id = o.manager_id
JOIN users r ON r.id = o.report_id
WHERE o.id = $1;

-- name: RescheduleOneOnOne :exec
UPDATE one_on_ones SET scheduled_at = sqlc.arg(scheduled_at)
WHERE id = sqlc.arg(id);

-- name: DeleteOneOnOne :exec
DELETE FROM one_on_ones WHERE id = $1;

-- name: ListOneOnOneItems :many
SELECT i.*, COALESCE(u.full_name, '')::text AS author_name
FROM one_on_one_items i
LEFT JOIN users u ON u.id = i.author_id
WHERE i.meeting_id = $1
ORDER BY i.created_at;

-- name: AddOneOnOneItem :one
INSERT INTO one_on_one_items (meeting_id, author_id, kind, body)
VALUES (sqlc.arg(meeting_id), sqlc.arg(author_id), sqlc.arg(kind),
        sqlc.arg(body))
RETURNING *;

-- name: SetOneOnOneItemDone :exec
UPDATE one_on_one_items SET done = sqlc.arg(done) WHERE id = sqlc.arg(id);

-- name: UpdateOneOnOneItem :exec
UPDATE one_on_one_items SET body = sqlc.arg(body) WHERE id = sqlc.arg(id);

-- name: DeleteOneOnOneItem :exec
DELETE FROM one_on_one_items WHERE id = $1;

-- name: GetOneOnOneItemMeeting :one
SELECT meeting_id FROM one_on_one_items WHERE id = $1;
