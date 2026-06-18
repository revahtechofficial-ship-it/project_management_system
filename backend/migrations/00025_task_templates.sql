-- +goose Up
-- +goose StatementBegin
CREATE TABLE task_templates (
    id               BIGSERIAL PRIMARY KEY,
    name             TEXT        NOT NULL,
    title            TEXT        NOT NULL DEFAULT '',
    description      TEXT        NOT NULL DEFAULT '',
    status           TEXT        NOT NULL DEFAULT 'todo',
    priority         TEXT        NOT NULL DEFAULT 'none',
    recurrence       TEXT        NOT NULL DEFAULT 'none',
    estimate_minutes INT         NOT NULL DEFAULT 0,
    tags             TEXT[]      NOT NULL DEFAULT '{}',
    project_id       BIGINT      REFERENCES projects (id) ON DELETE SET NULL,
    created_by       BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE task_templates;
-- +goose StatementEnd
