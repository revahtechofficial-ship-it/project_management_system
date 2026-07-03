-- name: ListExpenses :many
SELECT e.*, COALESCE(u.full_name, '')::text AS submitter_name,
       COALESCE(p.name, '')::text AS project_name
FROM expenses e
LEFT JOIN users u ON u.id = e.user_id
LEFT JOIN projects p ON p.id = e.project_id
ORDER BY e.spent_on DESC NULLS LAST, e.id DESC;

-- name: CreateExpense :one
INSERT INTO expenses (user_id, project_id, category, amount_cents, spent_on,
                      description, merchant, receipt_url)
VALUES (sqlc.arg(user_id), sqlc.arg(project_id), sqlc.arg(category),
        sqlc.arg(amount_cents), sqlc.arg(spent_on), sqlc.arg(description),
        sqlc.arg(merchant), sqlc.arg(receipt_url))
RETURNING *;

-- name: UpdateExpense :one
UPDATE expenses
SET project_id = sqlc.arg(project_id),
    category = sqlc.arg(category),
    amount_cents = sqlc.arg(amount_cents),
    spent_on = sqlc.arg(spent_on),
    description = sqlc.arg(description),
    merchant = sqlc.arg(merchant),
    receipt_url = sqlc.arg(receipt_url)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: SetExpenseStatus :one
UPDATE expenses SET status = sqlc.arg(status) WHERE id = sqlc.arg(id)
RETURNING *;

-- name: DeleteExpense :exec
DELETE FROM expenses WHERE id = $1;
