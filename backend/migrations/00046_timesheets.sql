-- +goose Up
-- +goose StatementBegin
CREATE TABLE timesheet_submissions (
    id           BIGSERIAL   PRIMARY KEY,
    user_id      BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    week_start   TIMESTAMPTZ NOT NULL,
    status       TEXT        NOT NULL DEFAULT 'submitted',
    minutes      INT         NOT NULL DEFAULT 0,
    note         TEXT        NOT NULL DEFAULT '',
    approver_id  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    decided_at   TIMESTAMPTZ,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, week_start)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_timesheets_status
    ON timesheet_submissions (status, submitted_at DESC);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE timesheet_submissions;
-- +goose StatementEnd
