-- name: ListComments :many
SELECT c.id, c.task_id, c.author_id, c.parent_id, c.body, c.created_at,
       u.full_name AS author_name
FROM comments c
LEFT JOIN users u ON u.id = c.author_id
WHERE c.task_id = $1
ORDER BY c.created_at ASC;

-- name: CreateComment :one
INSERT INTO comments (task_id, author_id, parent_id, body)
VALUES (sqlc.arg(task_id), sqlc.narg(author_id), sqlc.narg(parent_id),
        sqlc.arg(body))
RETURNING *;

-- name: GetComment :one
SELECT * FROM comments
WHERE id = $1;

-- name: DeleteComment :exec
DELETE FROM comments
WHERE id = $1;

-- name: ListActivity :many
SELECT a.id, a.task_id, a.actor_id, a.action, a.detail, a.created_at,
       u.full_name AS actor_name
FROM activity a
LEFT JOIN users u ON u.id = a.actor_id
WHERE a.task_id = $1
ORDER BY a.created_at DESC
LIMIT 50;

-- name: CreateActivity :exec
INSERT INTO activity (task_id, actor_id, action, detail)
VALUES ($1, $2, $3, $4);

-- name: ListRecentActivity :many
SELECT a.id, a.task_id, a.actor_id, a.action, a.detail, a.created_at,
       COALESCE(u.full_name, '')::text AS actor_name,
       COALESCE(t.title, '')::text     AS task_title
FROM activity a
LEFT JOIN users u ON u.id = a.actor_id
LEFT JOIN tasks t ON t.id = a.task_id
ORDER BY a.created_at DESC
LIMIT 200;
