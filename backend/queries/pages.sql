-- name: ListPages :many
SELECT p.id, p.type, p.title, p.icon, p.parent_id, p.is_template, p.category,
       p.owner_id, p.review_at, p.created_at, p.updated_at,
       COALESCE(cu.full_name, '')::text AS created_by_name,
       COALESCE(uu.full_name, '')::text AS updated_by_name,
       COALESCE(ow.full_name, '')::text AS owner_name
FROM pages p
LEFT JOIN users cu ON cu.id = p.created_by
LEFT JOIN users uu ON uu.id = p.updated_by
LEFT JOIN users ow ON ow.id = p.owner_id
WHERE p.type = sqlc.arg(type) AND p.is_template = sqlc.arg(is_template)
ORDER BY p.title ASC;

-- name: GetPage :one
SELECT p.id, p.type, p.title, p.icon, p.body, p.parent_id, p.is_template,
       p.category, p.owner_id, p.review_at, p.created_by, p.updated_by,
       p.created_at, p.updated_at,
       COALESCE(cu.full_name, '')::text AS created_by_name,
       COALESCE(uu.full_name, '')::text AS updated_by_name,
       COALESCE(ow.full_name, '')::text AS owner_name
FROM pages p
LEFT JOIN users cu ON cu.id = p.created_by
LEFT JOIN users uu ON uu.id = p.updated_by
LEFT JOIN users ow ON ow.id = p.owner_id
WHERE p.id = $1;

-- name: CreatePage :one
INSERT INTO pages (type, title, icon, body, parent_id, is_template, category,
                   owner_id, review_at, created_by, updated_by)
VALUES (sqlc.arg(type), sqlc.arg(title), sqlc.arg(icon), sqlc.arg(body),
        sqlc.narg(parent_id), sqlc.arg(is_template), sqlc.arg(category),
        sqlc.narg(owner_id), sqlc.narg(review_at),
        sqlc.narg(created_by), sqlc.narg(updated_by))
RETURNING *;

-- name: UpdatePage :exec
UPDATE pages
SET title = sqlc.arg(title), icon = sqlc.arg(icon), body = sqlc.arg(body),
    category = sqlc.arg(category), owner_id = sqlc.narg(owner_id),
    review_at = sqlc.narg(review_at),
    updated_by = sqlc.narg(updated_by), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: SetPageParent :exec
UPDATE pages SET parent_id = sqlc.narg(parent_id), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: DeletePage :exec
DELETE FROM pages WHERE id = $1;
