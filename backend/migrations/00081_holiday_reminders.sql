-- +goose Up
-- Holidays and festivals never notified anybody. Birthdays and personal events
-- did, because they belong to one person and carry their own remind_days — but
-- a holiday belongs to the country, so there is nowhere on the holiday itself
-- to hang "remind *me* three days before".
--
-- Hence a per-user setting. Null means never, which is the default: nobody gets
-- a notification they did not ask for.
ALTER TABLE users
    ADD COLUMN holiday_remind_days INT;

ALTER TABLE users
    ADD CONSTRAINT users_holiday_remind_check CHECK (
        holiday_remind_days IS NULL
        OR (holiday_remind_days >= 0 AND holiday_remind_days <= 60)
    );

COMMENT ON COLUMN users.holiday_remind_days IS
    'Days of notice for an upcoming public holiday. NULL = no reminders.';

-- One row per (person, holiday) they have been told about.
--
-- A holiday is shared, so the "reminded" flag cannot live on the holiday the
-- way it does on a personal event — telling one person would mark it told for
-- everybody. The primary key is the pair, which is also what stops a second
-- notification: the insert simply conflicts.
CREATE TABLE holiday_reminders_sent (
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    holiday_id BIGINT      NOT NULL REFERENCES holidays (id) ON DELETE CASCADE,
    sent_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, holiday_id)
);

-- +goose Down
DROP TABLE holiday_reminders_sent;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_holiday_remind_check;
ALTER TABLE users DROP COLUMN holiday_remind_days;
