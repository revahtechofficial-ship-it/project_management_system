-- +goose Up
-- Personal calendar entries: a note, a birthday, an anniversary, a meeting.
--
-- These are private. A holiday is the country's and a task is the team's, but
-- a birthday reminder is one person's, so every row is owned by a user and
-- the handler never lets anyone read another's.
--
-- The interesting column is `repeat_in`. A yearly event has to say *which
-- calendar* it repeats in, because the two disagree: a birthday kept on 15
-- Ashar falls on a different Gregorian day every year, and a birthday kept on
-- 9 July falls on a different BS day every year. Storing only the Gregorian
-- date and matching on month/day — the obvious implementation — silently turns
-- every Nepali birthday into the wrong day. Hence internal/nepdate, so the
-- server can work out when a BS anniversary next lands.
CREATE TABLE calendar_events (
    id           BIGSERIAL   PRIMARY KEY,
    user_id      BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    event_date   DATE        NOT NULL,
    kind         TEXT        NOT NULL DEFAULT 'note',
    title        TEXT        NOT NULL,
    note         TEXT        NOT NULL DEFAULT '',
    start_time   TIME,
    end_time     TIME,

    -- 'none' for a one-off, 'ad' to repeat on the same Gregorian day each
    -- year, 'bs' to repeat on the same Bikram Sambat day.
    repeat_in    TEXT        NOT NULL DEFAULT 'none',

    -- How many days ahead to remind, and null for no reminder at all.
    remind_days  INT,

    -- The next occurrence, in the Gregorian calendar. Materialised because a
    -- BS recurrence cannot be expressed as a SQL predicate — the month lengths
    -- are a lookup table, not a formula. The reminder sweep rolls it forward.
    next_occurs  DATE,

    -- Cleared whenever next_occurs moves, so one event can be reminded about
    -- year after year without ever being reminded twice for the same year.
    reminded_at  TIMESTAMPTZ,

    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT calendar_events_kind_check CHECK (kind IN
        ('note', 'birthday', 'anniversary', 'meeting', 'custom')),
    CONSTRAINT calendar_events_repeat_check CHECK (repeat_in IN
        ('none', 'ad', 'bs')),
    CONSTRAINT calendar_events_title_check CHECK (title <> ''),
    CONSTRAINT calendar_events_window_check CHECK (
        (start_time IS NULL AND end_time IS NULL)
        OR (start_time IS NOT NULL AND end_time IS NULL)
        OR (start_time IS NOT NULL AND end_time IS NOT NULL
            AND end_time >= start_time)
    ),
    CONSTRAINT calendar_events_remind_check CHECK (
        remind_days IS NULL OR (remind_days >= 0 AND remind_days <= 365)
    )
);

CREATE INDEX idx_calendar_events_user_date
    ON calendar_events (user_id, event_date);

-- The reminder sweep's only query: what is due, and not yet told.
CREATE INDEX idx_calendar_events_due
    ON calendar_events (next_occurs)
    WHERE remind_days IS NOT NULL AND reminded_at IS NULL;

-- +goose Down
DROP TABLE calendar_events;
