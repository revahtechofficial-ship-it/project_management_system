-- name: ListIncidents :many
SELECT i.*,
       COALESCE(a.full_name, '')::text AS assignee_name,
       COALESCE(r.full_name, '')::text AS reporter_name,
       COALESCE(p.name, '')::text AS project_name
FROM incidents i
LEFT JOIN users a ON a.id = i.assignee_id
LEFT JOIN users r ON r.id = i.reporter_id
LEFT JOIN projects p ON p.id = i.project_id
ORDER BY
    CASE i.status
        WHEN 'open' THEN 0
        WHEN 'investigating' THEN 1
        WHEN 'mitigated' THEN 2
        WHEN 'resolved' THEN 3
        ELSE 4
    END,
    CASE i.severity
        WHEN 'critical' THEN 0
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    i.created_at DESC;

-- name: CreateIncident :one
INSERT INTO incidents (title, description, kind, severity, project_id,
                       assignee_id, reporter_id, component)
VALUES (sqlc.arg(title), sqlc.arg(description), sqlc.arg(kind),
        sqlc.arg(severity), sqlc.arg(project_id), sqlc.arg(assignee_id),
        sqlc.arg(reporter_id), sqlc.arg(component))
RETURNING *;

-- name: UpdateIncident :one
UPDATE incidents
SET title = sqlc.arg(title),
    description = sqlc.arg(description),
    kind = sqlc.arg(kind),
    severity = sqlc.arg(severity),
    project_id = sqlc.arg(project_id),
    assignee_id = sqlc.arg(assignee_id),
    component = sqlc.arg(component)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: SetIncidentStatus :one
UPDATE incidents
SET status = sqlc.arg(status),
    resolved_at = sqlc.arg(resolved_at)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: DeleteIncident :exec
DELETE FROM incidents WHERE id = $1;
