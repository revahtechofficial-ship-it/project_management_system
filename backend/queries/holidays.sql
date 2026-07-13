-- name: ListHolidays :many
SELECT * FROM holidays
WHERE holiday_date >= sqlc.arg(from_date)
  AND holiday_date <= sqlc.arg(to_date)
ORDER BY holiday_date, id;

-- name: CreateHoliday :one
INSERT INTO holidays (holiday_date, name_en, name_ne, is_public, category,
                      description_en, description_ne, history_en, history_ne,
                      importance_en, importance_ne, celebration_en,
                      celebration_ne, aliases)
VALUES (sqlc.arg(holiday_date), sqlc.arg(name_en), sqlc.arg(name_ne),
        sqlc.arg(is_public), sqlc.arg(category),
        sqlc.arg(description_en), sqlc.arg(description_ne),
        sqlc.arg(history_en), sqlc.arg(history_ne),
        sqlc.arg(importance_en), sqlc.arg(importance_ne),
        sqlc.arg(celebration_en), sqlc.arg(celebration_ne),
        sqlc.arg(aliases))
ON CONFLICT (holiday_date, name_en) DO UPDATE
SET name_ne = EXCLUDED.name_ne,
    is_public = EXCLUDED.is_public,
    category = EXCLUDED.category,
    description_en = EXCLUDED.description_en,
    description_ne = EXCLUDED.description_ne,
    history_en = EXCLUDED.history_en,
    history_ne = EXCLUDED.history_ne,
    importance_en = EXCLUDED.importance_en,
    importance_ne = EXCLUDED.importance_ne,
    celebration_en = EXCLUDED.celebration_en,
    celebration_ne = EXCLUDED.celebration_ne,
    aliases = EXCLUDED.aliases
RETURNING *;

-- name: UpdateHoliday :one
UPDATE holidays
SET holiday_date = sqlc.arg(holiday_date),
    name_en = sqlc.arg(name_en),
    name_ne = sqlc.arg(name_ne),
    is_public = sqlc.arg(is_public),
    category = sqlc.arg(category),
    description_en = sqlc.arg(description_en),
    description_ne = sqlc.arg(description_ne),
    history_en = sqlc.arg(history_en),
    history_ne = sqlc.arg(history_ne),
    importance_en = sqlc.arg(importance_en),
    importance_ne = sqlc.arg(importance_ne),
    celebration_en = sqlc.arg(celebration_en),
    celebration_ne = sqlc.arg(celebration_ne),
    aliases = sqlc.arg(aliases)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: DeleteHoliday :exec
DELETE FROM holidays WHERE id = $1;
