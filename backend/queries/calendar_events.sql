-- name: ListCalendarEvents :many
SELECT * FROM calendar_events
WHERE user_id = sqlc.arg(user_id)
  AND event_date >= sqlc.arg(from_date)
  AND event_date <= sqlc.arg(to_date)
ORDER BY event_date, start_time NULLS FIRST, id;

-- Every repeating event the user owns, whatever its original date — a birthday
-- in 1994 must still show on this year's calendar.
-- name: ListRepeatingCalendarEvents :many
SELECT * FROM calendar_events
WHERE user_id = sqlc.arg(user_id)
  AND repeat_in <> 'none'
ORDER BY event_date, id;

-- name: GetCalendarEvent :one
SELECT * FROM calendar_events WHERE id = $1;

-- name: CreateCalendarEvent :one
INSERT INTO calendar_events (user_id, event_date, kind, title, note,
                             start_time, end_time, repeat_in, remind_days,
                             next_occurs)
VALUES (sqlc.arg(user_id), sqlc.arg(event_date), sqlc.arg(kind),
        sqlc.arg(title), sqlc.arg(note), sqlc.narg(start_time),
        sqlc.narg(end_time), sqlc.arg(repeat_in), sqlc.narg(remind_days),
        sqlc.narg(next_occurs))
RETURNING *;

-- Scoped by user_id as well as id, so a wrong id cannot edit someone else's
-- birthday — the check is in the WHERE clause, not only in the handler.
-- name: UpdateCalendarEvent :one
UPDATE calendar_events
SET event_date = sqlc.arg(event_date),
    kind = sqlc.arg(kind),
    title = sqlc.arg(title),
    note = sqlc.arg(note),
    start_time = sqlc.narg(start_time),
    end_time = sqlc.narg(end_time),
    repeat_in = sqlc.arg(repeat_in),
    remind_days = sqlc.narg(remind_days),
    next_occurs = sqlc.narg(next_occurs),
    reminded_at = NULL,
    updated_at = now()
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id)
RETURNING *;

-- name: DeleteCalendarEvent :execrows
DELETE FROM calendar_events
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id);

-- Events whose reminder is due: the next occurrence is within remind_days, and
-- nobody has been told yet.
-- name: DueCalendarReminders :many
SELECT * FROM calendar_events
WHERE remind_days IS NOT NULL
  AND reminded_at IS NULL
  AND next_occurs IS NOT NULL
  AND next_occurs <= CURRENT_DATE + remind_days
ORDER BY next_occurs, id
LIMIT 500;

-- name: MarkCalendarEventReminded :exec
UPDATE calendar_events SET reminded_at = now() WHERE id = $1;

-- Rolls a repeating event on to its next occurrence and clears the reminder
-- flag, so it can be reminded about again next year.
-- name: RollCalendarEvent :exec
UPDATE calendar_events
SET next_occurs = sqlc.arg(next_occurs), reminded_at = NULL
WHERE id = sqlc.arg(id);

-- Repeating events whose next occurrence has already gone by, so the sweep can
-- move them on.
-- name: StaleRepeatingEvents :many
SELECT * FROM calendar_events
WHERE repeat_in <> 'none'
  AND (next_occurs IS NULL OR next_occurs < CURRENT_DATE)
LIMIT 500;
