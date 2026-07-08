-- name: ListChecklistTemplates :many
SELECT * FROM checklist_templates
ORDER BY category, name, id;

-- name: GetChecklistTemplate :one
SELECT * FROM checklist_templates WHERE id = $1;

-- name: CreateChecklistTemplate :one
INSERT INTO checklist_templates (name, category, items, created_by)
VALUES (sqlc.arg(name), sqlc.arg(category), sqlc.arg(items),
        sqlc.arg(created_by))
RETURNING *;

-- name: UpdateChecklistTemplate :one
UPDATE checklist_templates
SET name = sqlc.arg(name),
    category = sqlc.arg(category),
    items = sqlc.arg(items)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: DeleteChecklistTemplate :exec
DELETE FROM checklist_templates WHERE id = $1;
