-- name: ListAssets :many
SELECT a.*, COALESCE(u.full_name, '')::text AS assignee_name
FROM assets a
LEFT JOIN users u ON u.id = a.assignee_id
ORDER BY a.name, a.id;

-- name: CreateAsset :one
INSERT INTO assets (name, kind, status, identifier, vendor, assignee_id,
                    cost_cents, purchased_on, expires_on, notes)
VALUES (sqlc.arg(name), sqlc.arg(kind), sqlc.arg(status), sqlc.arg(identifier),
        sqlc.arg(vendor), sqlc.arg(assignee_id), sqlc.arg(cost_cents),
        sqlc.arg(purchased_on), sqlc.arg(expires_on), sqlc.arg(notes))
RETURNING *;

-- name: UpdateAsset :one
UPDATE assets
SET name = sqlc.arg(name),
    kind = sqlc.arg(kind),
    status = sqlc.arg(status),
    identifier = sqlc.arg(identifier),
    vendor = sqlc.arg(vendor),
    assignee_id = sqlc.arg(assignee_id),
    cost_cents = sqlc.arg(cost_cents),
    purchased_on = sqlc.arg(purchased_on),
    expires_on = sqlc.arg(expires_on),
    notes = sqlc.arg(notes)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: DeleteAsset :exec
DELETE FROM assets WHERE id = $1;
