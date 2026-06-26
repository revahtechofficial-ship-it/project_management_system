-- +goose Up
-- +goose StatementBegin
CREATE TABLE releases (
    id          BIGSERIAL   PRIMARY KEY,
    name        TEXT        NOT NULL DEFAULT '',
    version     TEXT        NOT NULL DEFAULT '',
    status      TEXT        NOT NULL DEFAULT 'planned',
    target_date DATE,
    notes       TEXT        NOT NULL DEFAULT '',
    created_by  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks
    ADD COLUMN issue_type TEXT NOT NULL DEFAULT 'task';
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks
    ADD COLUMN severity TEXT NOT NULL DEFAULT 'none';
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks
    ADD COLUMN release_id BIGINT REFERENCES releases (id) ON DELETE SET NULL;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_tasks_release ON tasks (release_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN release_id;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN severity;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN issue_type;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE releases;
-- +goose StatementEnd
