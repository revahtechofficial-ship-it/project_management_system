-- +goose Up
-- Notifications become per-recipient: each row targets one user, with that
-- user's own read state. Tasks gain a flag so the reminder sweep delivers a
-- due/overdue reminder only once until the task is rescheduled or reopened.
ALTER TABLE notifications
    ADD COLUMN user_id BIGINT REFERENCES users(id) ON DELETE CASCADE;

CREATE INDEX idx_notifications_user ON notifications (user_id);

ALTER TABLE tasks
    ADD COLUMN reminder_sent BOOLEAN NOT NULL DEFAULT FALSE;

-- +goose Down
ALTER TABLE tasks DROP COLUMN reminder_sent;
DROP INDEX IF EXISTS idx_notifications_user;
ALTER TABLE notifications DROP COLUMN user_id;
