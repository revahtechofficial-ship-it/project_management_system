-- name: CreateFormResponse :one
INSERT INTO form_responses (page_id, submitted_by, answers)
VALUES (sqlc.arg(page_id), sqlc.narg(submitted_by), sqlc.arg(answers))
RETURNING *;

-- name: ListFormResponses :many
SELECT fr.id, fr.answers, fr.created_at,
       COALESCE(u.full_name, '')::text AS submitted_by_name
FROM form_responses fr
LEFT JOIN users u ON u.id = fr.submitted_by
WHERE fr.page_id = $1
ORDER BY fr.created_at DESC;

-- name: CountFormResponses :one
SELECT COUNT(*) FROM form_responses WHERE page_id = $1;
