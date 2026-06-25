-- name: ListCapacity :many
SELECT u.id AS user_id,
       u.full_name,
       u.email,
       COALESCE(mc.weekly_hours, 40)::int AS weekly_hours
FROM users u
LEFT JOIN member_capacity mc ON mc.user_id = u.id
ORDER BY u.full_name, u.email;

-- name: SetCapacity :exec
INSERT INTO member_capacity (user_id, weekly_hours)
VALUES (sqlc.arg(user_id), sqlc.arg(weekly_hours))
ON CONFLICT (user_id)
DO UPDATE SET weekly_hours = sqlc.arg(weekly_hours), updated_at = now();

-- name: ListAvailability :many
SELECT a.id, a.user_id, a.start_date, a.end_date, a.kind, a.note,
       a.created_at,
       COALESCE(u.full_name, '')::text AS user_name
FROM availability a
JOIN users u ON u.id = a.user_id
ORDER BY a.start_date DESC, a.id DESC;

-- name: CreateAvailability :one
INSERT INTO availability (user_id, start_date, end_date, kind, note, created_by)
VALUES (sqlc.arg(user_id), sqlc.arg(start_date), sqlc.arg(end_date),
        sqlc.arg(kind), sqlc.arg(note), sqlc.narg(created_by))
RETURNING id;

-- name: DeleteAvailability :exec
DELETE FROM availability WHERE id = $1;
