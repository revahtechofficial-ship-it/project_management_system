-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'member';
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE projects (
    id          BIGSERIAL   PRIMARY KEY,
    name        TEXT        NOT NULL,
    description TEXT        NOT NULL DEFAULT '',
    status      TEXT        NOT NULL DEFAULT 'active',
    due_date    TIMESTAMPTZ,
    created_by  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks
    ADD COLUMN project_id  BIGINT REFERENCES projects (id) ON DELETE SET NULL,
    ADD COLUMN assignee_id BIGINT REFERENCES users (id) ON DELETE SET NULL;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_tasks_project ON tasks (project_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_tasks_assignee ON tasks (assignee_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE notifications (
    id         BIGSERIAL   PRIMARY KEY,
    type       TEXT        NOT NULL,
    title      TEXT        NOT NULL,
    body       TEXT        NOT NULL DEFAULT '',
    read       BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE notifications;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN assignee_id, DROP COLUMN project_id;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE projects;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users DROP COLUMN role;
-- +goose StatementEnd
