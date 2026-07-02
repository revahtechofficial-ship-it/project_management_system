-- name: CreateApproval :one
INSERT INTO approvals (
    subject_type, subject_id, subject_title, requester_id, approver_id, note)
VALUES (
    sqlc.arg(subject_type), sqlc.arg(subject_id), sqlc.arg(subject_title),
    sqlc.arg(requester_id), sqlc.arg(approver_id), sqlc.arg(note))
RETURNING *;

-- name: ListPendingApprovals :many
SELECT a.*, u.full_name AS requester_name
FROM approvals a
JOIN users u ON u.id = a.requester_id
WHERE a.approver_id = sqlc.arg(approver_id) AND a.status = 'pending'
ORDER BY a.created_at DESC;

-- name: ListMyApprovalRequests :many
SELECT a.*, u.full_name AS approver_name
FROM approvals a
JOIN users u ON u.id = a.approver_id
WHERE a.requester_id = sqlc.arg(requester_id)
ORDER BY a.created_at DESC
LIMIT 50;

-- name: ListApprovalsForSubject :many
SELECT a.*,
       ru.full_name AS requester_name,
       au.full_name AS approver_name
FROM approvals a
JOIN users ru ON ru.id = a.requester_id
JOIN users au ON au.id = a.approver_id
WHERE a.subject_type = sqlc.arg(subject_type)
  AND a.subject_id = sqlc.arg(subject_id)
ORDER BY a.created_at DESC;

-- name: GetApproval :one
SELECT * FROM approvals WHERE id = $1;

-- name: DecideApproval :one
UPDATE approvals
SET status = sqlc.arg(status), decided_at = now()
WHERE id = sqlc.arg(id)
RETURNING *;
