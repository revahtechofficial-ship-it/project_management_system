-- name: ListDashboards :many
SELECT d.id, d.name, d.owner_id, d.visibility, d.widgets,
       d.created_at, d.updated_at,
       COALESCE(u.full_name, '')::text AS owner_name
FROM dashboards d
LEFT JOIN users u ON u.id = d.owner_id
WHERE d.visibility = 'workspace' OR d.owner_id = sqlc.narg(actor)
ORDER BY d.name ASC;

-- name: GetDashboard :one
SELECT d.id, d.name, d.owner_id, d.visibility, d.widgets,
       d.created_at, d.updated_at,
       COALESCE(u.full_name, '')::text AS owner_name
FROM dashboards d
LEFT JOIN users u ON u.id = d.owner_id
WHERE d.id = $1;

-- name: CreateDashboard :one
INSERT INTO dashboards (name, owner_id, visibility, widgets)
VALUES (sqlc.arg(name), sqlc.narg(owner_id), sqlc.arg(visibility),
        sqlc.arg(widgets))
RETURNING *;

-- name: UpdateDashboard :exec
UPDATE dashboards
SET name = sqlc.arg(name), visibility = sqlc.arg(visibility),
    widgets = sqlc.arg(widgets), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: DeleteDashboard :exec
DELETE FROM dashboards WHERE id = $1;
