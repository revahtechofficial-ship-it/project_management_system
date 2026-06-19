-- +goose Up
-- +goose StatementBegin
CREATE TABLE time_entries (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    task_id     BIGINT      REFERENCES tasks (id) ON DELETE SET NULL,
    minutes     INT         NOT NULL DEFAULT 0,
    started_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at    TIMESTAMPTZ,
    description TEXT        NOT NULL DEFAULT '',
    billable    BOOLEAN     NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_time_entries_user ON time_entries (user_id, started_at DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_time_entries_task ON time_entries (task_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE time_entries;
-- +goose StatementEnd
