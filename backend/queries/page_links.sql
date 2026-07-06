-- name: ClearPageLinks :exec
DELETE FROM page_links WHERE source_page_id = $1;

-- name: InsertPageLink :exec
INSERT INTO page_links (source_page_id, target_page_id)
VALUES (sqlc.arg(source_page_id), sqlc.arg(target_page_id))
ON CONFLICT (source_page_id, target_page_id) DO NOTHING;

-- name: FindPageByTitle :one
SELECT id FROM pages
WHERE lower(title) = lower(sqlc.arg(title)) AND is_template = false
ORDER BY id
LIMIT 1;

-- name: ListBacklinks :many
SELECT p.id, p.title, p.type, p.icon
FROM page_links l
JOIN pages p ON p.id = l.source_page_id
WHERE l.target_page_id = $1
ORDER BY p.title, p.id;
