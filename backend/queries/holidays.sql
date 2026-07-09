-- name: ListHolidays :many
SELECT * FROM holidays
WHERE holiday_date >= sqlc.arg(from_date)
  AND holiday_date <= sqlc.arg(to_date)
ORDER BY holiday_date, id;

-- name: CreateHoliday :one
INSERT INTO holidays (holiday_date, name_en, name_ne, is_public)
VALUES (sqlc.arg(holiday_date), sqlc.arg(name_en), sqlc.arg(name_ne),
        sqlc.arg(is_public))
ON CONFLICT (holiday_date, name_en) DO UPDATE
SET name_ne = EXCLUDED.name_ne, is_public = EXCLUDED.is_public
RETURNING *;

-- name: DeleteHoliday :exec
DELETE FROM holidays WHERE id = $1;
