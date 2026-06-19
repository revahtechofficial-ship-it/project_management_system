-- name: ListPages :many
SELECT p.id, p.type, p.title, p.icon, p.parent_id, p.is_template, p.category,
       p.owner_id, p.review_at, p.visibility, p.created_by,
       p.created_at, p.updated_at,
       COALESCE(cu.full_name, '')::text AS created_by_name,
       COALESCE(uu.full_name, '')::text AS updated_by_name,
       COALESCE(ow.full_name, '')::text AS owner_name,
       COALESCE(ps.permission, '')::text AS my_permission
FROM pages p
LEFT JOIN users cu ON cu.id = p.created_by
LEFT JOIN users uu ON uu.id = p.updated_by
LEFT JOIN users ow ON ow.id = p.owner_id
LEFT JOIN page_shares ps ON ps.page_id = p.id AND ps.user_id = sqlc.narg(actor)
WHERE p.type = sqlc.arg(type) AND p.is_template = sqlc.arg(is_template)
  AND (
    sqlc.arg(is_admin)::boolean
    OR p.visibility = 'workspace'
    OR p.created_by = sqlc.narg(actor)
    OR ps.user_id IS NOT NULL
  )
ORDER BY p.title ASC;

-- name: GetPage :one
SELECT p.id, p.type, p.title, p.icon, p.body, p.parent_id, p.is_template,
       p.category, p.owner_id, p.review_at, p.visibility,
       p.created_by, p.updated_by, p.created_at, p.updated_at,
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

-- name: SetPageVisibility :exec
UPDATE pages SET visibility = sqlc.arg(visibility), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: DeletePage :exec
DELETE FROM pages WHERE id = $1;

-- name: GetPageShare :one
SELECT permission FROM page_shares WHERE page_id = $1 AND user_id = $2;

-- name: ListPageShares :many
SELECT s.user_id, s.permission, u.full_name, u.email, u.avatar
FROM page_shares s
JOIN users u ON u.id = s.user_id
WHERE s.page_id = $1
ORDER BY u.full_name;

-- name: UpsertPageShare :exec
INSERT INTO page_shares (page_id, user_id, permission)
VALUES (sqlc.arg(page_id), sqlc.arg(user_id), sqlc.arg(permission))
ON CONFLICT (page_id, user_id) DO UPDATE SET permission = EXCLUDED.permission;

-- name: RemovePageShare :exec
DELETE FROM page_shares WHERE page_id = $1 AND user_id = $2;
