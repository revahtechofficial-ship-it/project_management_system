-- name: ListSpaces :many
SELECT * FROM spaces ORDER BY position, id;

-- name: CreateSpace :one
INSERT INTO spaces (name, color, position, created_by)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: UpdateSpace :one
UPDATE spaces SET name = $2, color = $3 WHERE id = $1 RETURNING *;

-- name: MaxSpacePosition :one
SELECT COALESCE(MAX(position), -1)::int FROM spaces;

-- name: DeleteSpace :exec
DELETE FROM spaces WHERE id = $1;

-- name: ListFolders :many
SELECT * FROM folders ORDER BY position, id;

-- name: CreateFolder :one
INSERT INTO folders (space_id, name, position)
VALUES ($1, $2, $3)
RETURNING *;

-- name: UpdateFolder :one
UPDATE folders SET name = $2 WHERE id = $1 RETURNING *;

-- name: MaxFolderPosition :one
SELECT COALESCE(MAX(position), -1)::int FROM folders WHERE space_id = $1;

-- name: DeleteFolder :exec
DELETE FROM folders WHERE id = $1;
