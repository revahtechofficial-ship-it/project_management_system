-- name: ListBudgets :many
SELECT b.id, b.project_id, b.amount_cents, b.hourly_rate_cents, b.notes,
       b.created_at, b.updated_at,
       COALESCE(p.name, '')::text AS project_name,
       COALESCE((
           SELECT SUM(e.amount_cents) FROM expenses e
           WHERE e.project_id = b.project_id
             AND e.status IN ('approved', 'reimbursed')
       ), 0)::bigint AS expense_cents,
       COALESCE((
           SELECT SUM(t.minutes) FROM time_entries t
           JOIN tasks tk ON tk.id = t.task_id
           WHERE tk.project_id = b.project_id AND t.billable = true
       ), 0)::bigint AS billable_minutes
FROM project_budgets b
LEFT JOIN projects p ON p.id = b.project_id
ORDER BY p.name, b.id;

-- name: UpsertBudget :one
INSERT INTO project_budgets (project_id, amount_cents, hourly_rate_cents,
                             notes, updated_at)
VALUES (sqlc.arg(project_id), sqlc.arg(amount_cents),
        sqlc.arg(hourly_rate_cents), sqlc.arg(notes), now())
ON CONFLICT (project_id) DO UPDATE
SET amount_cents = EXCLUDED.amount_cents,
    hourly_rate_cents = EXCLUDED.hourly_rate_cents,
    notes = EXCLUDED.notes,
    updated_at = now()
RETURNING *;

-- name: DeleteBudget :exec
DELETE FROM project_budgets WHERE id = $1;
