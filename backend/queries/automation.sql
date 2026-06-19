-- name: ListAutomationRules :many
SELECT * FROM automation_rules ORDER BY created_at DESC;

-- name: ListEnabledRulesByTrigger :many
SELECT * FROM automation_rules
WHERE enabled = true AND trigger = $1
ORDER BY id;

-- name: GetAutomationRule :one
SELECT * FROM automation_rules WHERE id = $1;

-- name: CreateAutomationRule :one
INSERT INTO automation_rules (name, enabled, trigger, conditions, actions,
                              created_by)
VALUES (sqlc.arg(name), sqlc.arg(enabled), sqlc.arg(trigger),
        sqlc.arg(conditions), sqlc.arg(actions), sqlc.narg(created_by))
RETURNING *;

-- name: UpdateAutomationRule :exec
UPDATE automation_rules
SET name = sqlc.arg(name), enabled = sqlc.arg(enabled),
    trigger = sqlc.arg(trigger), conditions = sqlc.arg(conditions),
    actions = sqlc.arg(actions), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: SetAutomationRuleEnabled :exec
UPDATE automation_rules SET enabled = sqlc.arg(enabled), updated_at = now()
WHERE id = sqlc.arg(id);

-- name: DeleteAutomationRule :exec
DELETE FROM automation_rules WHERE id = $1;
