-- name: CreateLeave :one
INSERT INTO leave_requests (user_id, type, start_date, end_date, note)
VALUES (sqlc.arg(user_id), sqlc.arg(type), sqlc.arg(start_date),
        sqlc.arg(end_date), sqlc.arg(note))
RETURNING *;

-- name: ListMyLeave :many
SELECT l.*, COALESCE(a.full_name, '')::text AS approver_name
FROM leave_requests l
LEFT JOIN users a ON a.id = l.approver_id
WHERE l.user_id = $1
ORDER BY l.start_date DESC;

-- name: ListPendingLeave :many
SELECT l.*, u.full_name AS user_name, u.avatar
FROM leave_requests l
JOIN users u ON u.id = l.user_id
WHERE l.status = 'pending'
ORDER BY l.start_date;

-- name: ListLeaveInRange :many
SELECT l.*, u.full_name AS user_name, u.avatar
FROM leave_requests l
JOIN users u ON u.id = l.user_id
WHERE l.status = 'approved'
  AND l.start_date < sqlc.arg(range_end)
  AND l.end_date >= sqlc.arg(range_start)
ORDER BY l.start_date;

-- name: DecideLeave :one
UPDATE leave_requests
SET status = sqlc.arg(status),
    approver_id = sqlc.arg(approver_id),
    decided_at = now()
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: CancelLeave :exec
DELETE FROM leave_requests
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id)
  AND status = 'pending';

-- name: UsedLeaveDays :one
SELECT COALESCE(SUM((DATE(end_date) - DATE(start_date)) + 1), 0)::int
FROM leave_requests
WHERE user_id = sqlc.arg(user_id)
  AND status = 'approved'
  AND type = 'vacation'
  AND start_date >= sqlc.arg(year_start)
  AND start_date < sqlc.arg(year_end);
