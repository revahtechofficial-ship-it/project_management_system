-- name: ListPages :many
SELECT p.id, p.type, p.title, p.icon, p.parent_id, p.created_at, p.updated_at,
       COALESCE(cu.full_name, '')::text AS created_by_name,
       COALESCE(uu.full_name, '')::text AS updated_by_name
FROM pages p
LEFT JOIN users cu ON cu.id = p.created_by
LEFT JOIN users uu ON uu.id = p.updated_by
WHERE p.type = sqlc.arg(type)
ORDER BY p.title ASC;

-- name: GetPage :one
SELECT p.id, p.type, p.title, p.icon, p.body, p.parent_id,
       p.created_by, p.updated_by, p.created_at, p.updated_at,
       COALESCE(cu.full_name, '')::text AS created_by_name,
       COALESCE(uu.full_name, '')::text AS updated_by_name
FROM pages p
LEFT JOIN users cu ON cu.id = p.created_by
LEFT JOIN users uu ON uu.id = p.updated_by
WHERE p.id = $1;

-- name: CreatePage :one
INSERT INTO pages (type, title, icon, body, parent_id, created_by, updated_by)
VALUES (sqlc.arg(type), sqlc.arg(title), sqlc.arg(icon), sqlc.arg(body),
        sqlc.narg(parent_id), sqlc.narg(created_by), sqlc.narg(updated_by))
RETURNING *;

-- name: UpdatePage :exec
UPDATE pages
SET title = sqlc.arg(title), icon = sqlc.arg(icon), body = sqlc.arg(body),
    updated_by = sqlc.narg(updated_by), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: SetPageParent :exec
UPDATE pages SET parent_id = sqlc.narg(parent_id), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: DeletePage :exec
DELETE FROM pages WHERE id = $1;
