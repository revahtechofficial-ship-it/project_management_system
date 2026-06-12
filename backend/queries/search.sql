-- name: SearchTasks :many
-- Full-text-ish search across top-level tasks: title, description, project
-- name and tags. Paginated with limit/offset.
SELECT t.*,
       p.name      AS project_name,
       u.full_name AS assignee_name,
       COALESCE(st.total, 0)::int AS subtask_count,
       COALESCE(st.done, 0)::int  AS subtask_done_count
FROM tasks t
LEFT JOIN projects p ON p.id = t.project_id
LEFT JOIN users u ON u.id = t.assignee_id
LEFT JOIN (
    SELECT parent_id,
           COUNT(*)                     AS total,
           COUNT(*) FILTER (WHERE done) AS done
    FROM tasks
    WHERE parent_id IS NOT NULL
    GROUP BY parent_id
) st ON st.parent_id = t.id
WHERE t.parent_id IS NULL
  AND (
        t.title ILIKE '%' || sqlc.arg(query) || '%'
     OR t.description ILIKE '%' || sqlc.arg(query) || '%'
     OR p.name ILIKE '%' || sqlc.arg(query) || '%'
     OR EXISTS (
          SELECT 1 FROM unnest(t.tags) tg
          WHERE tg ILIKE '%' || sqlc.arg(query) || '%'
        )
  )
ORDER BY t.created_at DESC
LIMIT sqlc.arg(lim) OFFSET sqlc.arg(off);

-- name: SearchProjects :many
SELECT id, name, status, due_date
FROM projects
WHERE name ILIKE '%' || sqlc.arg(query) || '%'
   OR description ILIKE '%' || sqlc.arg(query) || '%'
ORDER BY created_at DESC
LIMIT sqlc.arg(lim);
