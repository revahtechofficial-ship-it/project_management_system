-- name: ListAttachments :many
SELECT a.id, a.task_id, a.uploader_id, a.filename, a.content_type, a.size,
       a.created_at, u.full_name AS uploader_name
FROM attachments a
LEFT JOIN users u ON u.id = a.uploader_id
WHERE a.task_id = $1
ORDER BY a.created_at DESC;

-- name: CreateAttachment :one
INSERT INTO attachments (task_id, uploader_id, filename, stored_name, content_type, size)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetAttachment :one
SELECT * FROM attachments
WHERE id = $1;

-- name: DeleteAttachment :exec
DELETE FROM attachments
WHERE id = $1;
