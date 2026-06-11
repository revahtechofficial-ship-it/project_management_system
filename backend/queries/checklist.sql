-- name: ListChecklist :many
SELECT * FROM checklist_items
WHERE task_id = $1
ORDER BY position ASC, id ASC;

-- name: CreateChecklistItem :one
INSERT INTO checklist_items (task_id, content, position)
VALUES ($1, $2, $3)
RETURNING *;

-- name: SetChecklistItemDone :one
UPDATE checklist_items
SET done = $2
WHERE id = $1
RETURNING *;

-- name: DeleteChecklistItem :exec
DELETE FROM checklist_items
WHERE id = $1;

-- name: MaxChecklistPosition :one
SELECT COALESCE(MAX(position), 0)::int FROM checklist_items
WHERE task_id = $1;
