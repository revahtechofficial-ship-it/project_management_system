-- name: ListReleases :many
SELECT id, name, version, status, target_date, notes, created_at, updated_at
FROM releases
ORDER BY target_date NULLS LAST, created_at;

-- name: CreateRelease :one
INSERT INTO releases (name, version, status, target_date, notes, created_by)
VALUES (sqlc.arg(name), sqlc.arg(version), sqlc.arg(status),
        sqlc.narg(target_date), sqlc.arg(notes), sqlc.narg(created_by))
RETURNING id, name, version, status, target_date, notes, created_at, updated_at;

-- name: UpdateRelease :exec
UPDATE releases
SET name = sqlc.arg(name), version = sqlc.arg(version),
    status = sqlc.arg(status), target_date = sqlc.narg(target_date),
    notes = sqlc.arg(notes), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: DeleteRelease :exec
DELETE FROM releases WHERE id = $1;
