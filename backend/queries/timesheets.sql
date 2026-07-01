-- name: WeekMinutes :one
SELECT COALESCE(SUM(minutes), 0)::int FROM time_entries
WHERE user_id = sqlc.arg(user_id)
  AND started_at >= sqlc.arg(week_start)
  AND started_at < sqlc.arg(week_end);

-- name: SubmitTimesheet :one
INSERT INTO timesheet_submissions (
    user_id, week_start, minutes, note, status, submitted_at)
VALUES (
    sqlc.arg(user_id), sqlc.arg(week_start), sqlc.arg(minutes),
    sqlc.arg(note), 'submitted', now())
ON CONFLICT (user_id, week_start) DO UPDATE
    SET minutes = EXCLUDED.minutes,
        note = EXCLUDED.note,
        status = 'submitted',
        submitted_at = now(),
        approver_id = NULL,
        decided_at = NULL
RETURNING *;

-- name: ListMyTimesheets :many
SELECT t.*, COALESCE(a.full_name, '')::text AS approver_name
FROM timesheet_submissions t
LEFT JOIN users a ON a.id = t.approver_id
WHERE t.user_id = $1
ORDER BY t.week_start DESC
LIMIT 26;

-- name: ListPendingTimesheets :many
SELECT t.*, u.full_name AS user_name
FROM timesheet_submissions t
JOIN users u ON u.id = t.user_id
WHERE t.status = 'submitted'
ORDER BY t.submitted_at ASC;

-- name: DecideTimesheet :one
UPDATE timesheet_submissions
SET status = sqlc.arg(status),
    approver_id = sqlc.arg(approver_id),
    decided_at = now()
WHERE id = sqlc.arg(id)
RETURNING *;
