-- name: ListCustomFields :many
SELECT * FROM custom_fields
ORDER BY position, id;

-- name: CreateCustomField :one
INSERT INTO custom_fields (name, field_type, options, position)
VALUES ($1, $2, $3,
        COALESCE((SELECT MAX(position) + 1 FROM custom_fields), 0))
RETURNING *;

-- name: UpdateCustomField :one
UPDATE custom_fields
SET name = $2, options = $3
WHERE id = $1
RETURNING *;

-- name: DeleteCustomField :exec
DELETE FROM custom_fields WHERE id = $1;

-- name: ListTaskFieldValues :many
SELECT field_id, value FROM task_field_values
WHERE task_id = $1;

-- name: SetTaskFieldValue :exec
INSERT INTO task_field_values (task_id, field_id, value)
VALUES ($1, $2, $3)
ON CONFLICT (task_id, field_id) DO UPDATE SET value = EXCLUDED.value;

-- name: DeleteTaskFieldValue :exec
DELETE FROM task_field_values
WHERE task_id = $1 AND field_id = $2;
