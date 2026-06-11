-- name: ListMembers :many
SELECT u.id,
       u.email,
       u.full_name,
       u.role,
       u.created_at,
       COALESCE(o.open, 0)::int AS open_tasks,
       COALESCE(d.done, 0)::int AS completed_tasks
FROM users u
LEFT JOIN (
    SELECT assignee_id, COUNT(*) AS open
    FROM tasks
    WHERE NOT done AND assignee_id IS NOT NULL
    GROUP BY assignee_id
) o ON o.assignee_id = u.id
LEFT JOIN (
    SELECT assignee_id, COUNT(*) AS done
    FROM tasks
    WHERE done AND assignee_id IS NOT NULL
    GROUP BY assignee_id
) d ON d.assignee_id = u.id
ORDER BY completed_tasks DESC, u.created_at ASC;
