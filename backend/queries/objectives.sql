-- name: ListObjectives :many
SELECT o.id, o.title, o.description, o.owner_id, o.parent_id, o.period,
       o.status, o.created_by, o.created_at, o.updated_at,
       COALESCE(ow.full_name, '')::text AS owner_name
FROM objectives o
LEFT JOIN users ow ON ow.id = o.owner_id
ORDER BY o.created_at ASC;

-- name: GetObjective :one
SELECT o.id, o.title, o.description, o.owner_id, o.parent_id, o.period,
       o.status, o.created_by, o.created_at, o.updated_at,
       COALESCE(ow.full_name, '')::text AS owner_name
FROM objectives o
LEFT JOIN users ow ON ow.id = o.owner_id
WHERE o.id = $1;

-- name: CreateObjective :one
INSERT INTO objectives (title, description, owner_id, parent_id, period,
                        status, created_by)
VALUES (sqlc.arg(title), sqlc.arg(description), sqlc.narg(owner_id),
        sqlc.narg(parent_id), sqlc.arg(period), sqlc.arg(status),
        sqlc.narg(created_by))
RETURNING id;

-- name: UpdateObjective :exec
UPDATE objectives
SET title = sqlc.arg(title), description = sqlc.arg(description),
    owner_id = sqlc.narg(owner_id), parent_id = sqlc.narg(parent_id),
    period = sqlc.arg(period), status = sqlc.arg(status), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: DeleteObjective :exec
DELETE FROM objectives WHERE id = $1;

-- name: ListAllKeyResults :many
SELECT id, objective_id, title, start_value, current_value, target_value,
       unit, position, created_at
FROM key_results
ORDER BY objective_id, position, id;

-- name: CreateKeyResult :one
INSERT INTO key_results (objective_id, title, start_value, current_value,
                         target_value, unit, position)
VALUES (sqlc.arg(objective_id), sqlc.arg(title), sqlc.arg(start_value),
        sqlc.arg(current_value), sqlc.arg(target_value), sqlc.arg(unit),
        sqlc.arg(position))
RETURNING id;

-- name: UpdateKeyResult :exec
UPDATE key_results
SET title = sqlc.arg(title), start_value = sqlc.arg(start_value),
    current_value = sqlc.arg(current_value),
    target_value = sqlc.arg(target_value), unit = sqlc.arg(unit)
WHERE id = sqlc.arg(id);

-- name: DeleteKeyResult :exec
DELETE FROM key_results WHERE id = $1;

-- name: GetKeyResultObjective :one
SELECT objective_id FROM key_results WHERE id = $1;
