-- name: ListInvoices :many
SELECT i.*, COALESCE(p.name, '')::text AS project_name,
       COALESCE((
           SELECT SUM(l.amount_cents) FROM invoice_lines l
           WHERE l.invoice_id = i.id
       ), 0)::bigint AS total_cents,
       COALESCE((
           SELECT COUNT(*) FROM invoice_lines l WHERE l.invoice_id = i.id
       ), 0)::bigint AS line_count
FROM invoices i
LEFT JOIN projects p ON p.id = i.project_id
ORDER BY i.id DESC;

-- name: GetInvoice :one
SELECT i.*, COALESCE(p.name, '')::text AS project_name,
       COALESCE((
           SELECT SUM(l.amount_cents) FROM invoice_lines l
           WHERE l.invoice_id = i.id
       ), 0)::bigint AS total_cents
FROM invoices i
LEFT JOIN projects p ON p.id = i.project_id
WHERE i.id = $1;

-- name: CreateInvoice :one
INSERT INTO invoices (number, project_id, client_name, client_email,
                      issue_date, due_date, notes)
VALUES ('INV-' || lpad(nextval('invoice_number_seq')::text, 4, '0'),
        sqlc.arg(project_id), sqlc.arg(client_name), sqlc.arg(client_email),
        sqlc.arg(issue_date), sqlc.arg(due_date), sqlc.arg(notes))
RETURNING *;

-- name: SetInvoiceStatus :one
UPDATE invoices SET status = sqlc.arg(status) WHERE id = sqlc.arg(id)
RETURNING *;

-- name: DeleteInvoice :exec
DELETE FROM invoices WHERE id = $1;

-- name: ListInvoiceLines :many
SELECT * FROM invoice_lines WHERE invoice_id = $1 ORDER BY sort, id;

-- name: AddInvoiceLine :one
INSERT INTO invoice_lines (invoice_id, description, quantity_minutes,
                           rate_cents, amount_cents, sort)
VALUES (sqlc.arg(invoice_id), sqlc.arg(description),
        sqlc.arg(quantity_minutes), sqlc.arg(rate_cents),
        sqlc.arg(amount_cents), sqlc.arg(sort))
RETURNING *;

-- name: DeleteInvoiceLine :exec
DELETE FROM invoice_lines WHERE id = $1;

-- name: GetProjectRate :one
SELECT COALESCE((
    SELECT hourly_rate_cents FROM project_budgets WHERE project_id = $1
), 0)::bigint;

-- name: UnbilledTimeByUser :many
SELECT u.id AS user_id, COALESCE(u.full_name, '')::text AS user_name,
       SUM(te.minutes)::bigint AS minutes
FROM time_entries te
JOIN tasks tk ON tk.id = te.task_id
LEFT JOIN users u ON u.id = te.user_id
WHERE tk.project_id = $1 AND te.billable = true AND te.invoice_id IS NULL
GROUP BY u.id, u.full_name
HAVING SUM(te.minutes) > 0
ORDER BY u.full_name;

-- name: MarkProjectTimeInvoiced :exec
UPDATE time_entries te
SET invoice_id = sqlc.arg(invoice_id)
FROM tasks tk
WHERE te.task_id = tk.id
  AND tk.project_id = sqlc.arg(project_id)
  AND te.billable = true
  AND te.invoice_id IS NULL;

-- name: ReleaseInvoiceTime :exec
UPDATE time_entries SET invoice_id = NULL WHERE invoice_id = $1;
