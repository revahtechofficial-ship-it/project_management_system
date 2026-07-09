-- name: ListProjectMembers :many
SELECT pm.project_id, pm.user_id, pm.role, pm.created_at,
       COALESCE(u.full_name, '')::text AS user_name,
       COALESCE(u.email, '')::text     AS user_email
FROM project_members pm
JOIN users u ON u.id = pm.user_id
WHERE pm.project_id = $1
ORDER BY u.full_name, pm.user_id;

-- name: UpsertProjectMember :exec
INSERT INTO project_members (project_id, user_id, role)
VALUES (sqlc.arg(project_id), sqlc.arg(user_id), sqlc.arg(role))
ON CONFLICT (project_id, user_id) DO UPDATE SET role = EXCLUDED.role;

-- name: DeleteProjectMember :exec
DELETE FROM project_members
WHERE project_id = sqlc.arg(project_id) AND user_id = sqlc.arg(user_id);

-- name: CountProjectMembers :one
SELECT COUNT(*) FROM project_members WHERE project_id = $1;

-- name: GetProjectMemberRole :one
SELECT role FROM project_members
WHERE project_id = sqlc.arg(project_id) AND user_id = sqlc.arg(user_id);

-- name: ListProjectAccess :many
SELECT p.id AS project_id,
       COALESCE(mine.role, '')::text AS my_role,
       COALESCE(cnt.n, 0)::bigint    AS member_count
FROM projects p
LEFT JOIN project_members mine
       ON mine.project_id = p.id AND mine.user_id = sqlc.arg(user_id)
LEFT JOIN (
    SELECT project_id, COUNT(*) AS n FROM project_members GROUP BY project_id
) cnt ON cnt.project_id = p.id;
