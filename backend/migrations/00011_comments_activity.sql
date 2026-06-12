-- +goose Up
-- +goose StatementBegin
CREATE TABLE comments (
    id         BIGSERIAL   PRIMARY KEY,
    task_id    BIGINT      NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    author_id  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    body       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_comments_task ON comments (task_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE activity (
    id         BIGSERIAL   PRIMARY KEY,
    task_id    BIGINT      NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    actor_id   BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    action     TEXT        NOT NULL,
    detail     TEXT        NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_activity_task ON activity (task_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE activity;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE comments;
-- +goose StatementEnd
