-- name: ListClients :many
SELECT c.*,
       COALESCE((
           SELECT COUNT(*) FROM projects p WHERE p.client_id = c.id
       ), 0)::bigint AS project_count
FROM clients c
ORDER BY c.name, c.id;

-- name: CreateClient :one
INSERT INTO clients (name, company, email, portal_token)
VALUES (sqlc.arg(name), sqlc.arg(company), sqlc.arg(email),
        sqlc.arg(portal_token))
RETURNING *;

-- name: UpdateClient :one
UPDATE clients
SET name = sqlc.arg(name),
    company = sqlc.arg(company),
    email = sqlc.arg(email)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: DeleteClient :exec
DELETE FROM clients WHERE id = $1;

-- name: GetClientByToken :one
SELECT * FROM clients WHERE portal_token = $1;

-- name: ListProjectsWithClientFlag :many
SELECT p.id, p.name, COALESCE(p.client_id = $1, false)::bool AS assigned
FROM projects p
ORDER BY p.name, p.id;

-- name: ClearClientProjects :exec
UPDATE projects SET client_id = NULL WHERE client_id = $1;

-- name: SetProjectClient :exec
UPDATE projects SET client_id = sqlc.arg(client_id) WHERE id = sqlc.arg(id);

-- name: ListClientProjects :many
SELECT p.id, p.name, p.description, p.status, p.due_date,
       COALESCE((
           SELECT COUNT(*) FROM tasks t WHERE t.project_id = p.id
       ), 0)::int AS total_tasks,
       COALESCE((
           SELECT COUNT(*) FROM tasks t WHERE t.project_id = p.id AND t.done
       ), 0)::int AS done_tasks
FROM projects p
WHERE p.client_id = $1
ORDER BY p.name, p.id;

-- name: ListClientInvoices :many
SELECT i.id, i.number, i.status, i.issue_date, i.due_date, i.created_at,
       COALESCE((
           SELECT SUM(l.amount_cents) FROM invoice_lines l
           WHERE l.invoice_id = i.id
       ), 0)::bigint AS total_cents
FROM invoices i
JOIN projects p ON p.id = i.project_id
WHERE p.client_id = $1 AND i.status <> 'void'
ORDER BY i.id DESC;
