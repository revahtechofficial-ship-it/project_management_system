-- name: SnapshotPageVersion :exec
INSERT INTO page_versions (page_id, title, body, edited_by, edited_at)
VALUES (sqlc.arg(page_id), sqlc.arg(title), sqlc.arg(body),
        sqlc.arg(edited_by), sqlc.arg(edited_at));

-- name: HasRecentPageVersion :one
SELECT EXISTS(
    SELECT 1 FROM page_versions
    WHERE page_id = sqlc.arg(page_id) AND created_at > sqlc.arg(since)
)::bool;

-- name: ListPageVersions :many
SELECT v.id, v.page_id, v.title, v.body, v.edited_by, v.edited_at,
       v.created_at, COALESCE(u.full_name, '')::text AS editor_name
FROM page_versions v
LEFT JOIN users u ON u.id = v.edited_by
WHERE v.page_id = $1
ORDER BY v.created_at DESC
LIMIT 50;

-- name: GetPageVersion :one
SELECT * FROM page_versions WHERE id = $1;

-- name: RestorePageContent :exec
UPDATE pages
SET title = sqlc.arg(title),
    body = sqlc.arg(body),
    updated_by = sqlc.arg(updated_by),
    updated_at = now()
WHERE id = sqlc.arg(id);
