-- +goose Up
-- +goose StatementBegin
CREATE TABLE task_watchers (
    task_id    BIGINT      NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (task_id, user_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_task_watchers_user ON task_watchers (user_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE task_watchers;
-- +goose StatementEnd
