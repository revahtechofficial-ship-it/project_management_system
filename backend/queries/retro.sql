-- name: ListRetroItems :many
SELECT r.*, COALESCE(u.full_name, '')::text AS author_name
FROM retro_items r
LEFT JOIN users u ON u.id = r.author_id
WHERE r.sprint_id = $1
ORDER BY r.created_at;

-- name: AddRetroItem :one
INSERT INTO retro_items (sprint_id, author_id, kind, body)
VALUES (sqlc.arg(sprint_id), sqlc.arg(author_id), sqlc.arg(kind),
        sqlc.arg(body))
RETURNING *;

-- name: SetRetroDone :exec
UPDATE retro_items SET done = sqlc.arg(done) WHERE id = sqlc.arg(id);

-- name: DeleteRetroItem :exec
DELETE FROM retro_items WHERE id = $1;
