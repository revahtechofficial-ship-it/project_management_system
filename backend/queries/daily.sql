-- name: ListObservances :many
SELECT * FROM observances ORDER BY month, day, id;

-- name: CreateObservance :one
INSERT INTO observances (month, day, name_en, name_ne, scope, note_en,
                         note_ne, source)
VALUES (sqlc.arg(month), sqlc.arg(day), sqlc.arg(name_en), sqlc.arg(name_ne),
        sqlc.arg(scope), sqlc.arg(note_en), sqlc.arg(note_ne),
        sqlc.arg(source))
ON CONFLICT (month, day, name_en) DO UPDATE
SET name_ne = EXCLUDED.name_ne,
    scope = EXCLUDED.scope,
    note_en = EXCLUDED.note_en,
    note_ne = EXCLUDED.note_ne,
    source = EXCLUDED.source
RETURNING *;

-- name: DeleteObservance :exec
DELETE FROM observances WHERE id = $1;

-- name: ListQuotes :many
SELECT * FROM quotes ORDER BY id;

-- name: CountQuotes :one
SELECT count(*) FROM quotes;

-- The quote for a given day, chosen by rotating through the table on the day
-- of the year. Deterministic: the same day always gives the same quote, with
-- no scheduler and no stored "quote of the day" row to go stale.
-- name: QuoteForDay :one
SELECT * FROM quotes
ORDER BY id
OFFSET (sqlc.arg(day_index)::bigint % GREATEST((SELECT count(*) FROM quotes), 1))
LIMIT 1;

-- name: CreateQuote :one
INSERT INTO quotes (text_en, text_ne, author, source)
VALUES (sqlc.arg(text_en), sqlc.arg(text_ne), sqlc.arg(author),
        sqlc.arg(source))
RETURNING *;

-- name: DeleteQuote :exec
DELETE FROM quotes WHERE id = $1;

-- Every reading that covers a day: the daily one, the week it sits in, and the
-- month. One query, so the card can show all three without three round trips.
-- name: RashifalForDay :many
SELECT * FROM rashifal
WHERE from_date <= sqlc.arg(on_date)
  AND to_date >= sqlc.arg(on_date)
ORDER BY rashi, period;

-- name: CreateRashifal :one
INSERT INTO rashifal (rashi, period, from_date, to_date, text_en, text_ne,
                      source)
VALUES (sqlc.arg(rashi), sqlc.arg(period), sqlc.arg(from_date),
        sqlc.arg(to_date), sqlc.arg(text_en), sqlc.arg(text_ne),
        sqlc.arg(source))
ON CONFLICT (rashi, period, from_date) DO UPDATE
SET to_date = EXCLUDED.to_date,
    text_en = EXCLUDED.text_en,
    text_ne = EXCLUDED.text_ne,
    source = EXCLUDED.source
RETURNING *;

-- name: DeleteRashifal :exec
DELETE FROM rashifal WHERE id = $1;
