-- +goose Up
-- +goose StatementBegin
ALTER TABLE tasks
    ADD COLUMN parent_id  BIGINT REFERENCES tasks (id) ON DELETE CASCADE,
    ADD COLUMN recurrence TEXT NOT NULL DEFAULT 'none';
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_tasks_parent ON tasks (parent_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE checklist_items (
    id         BIGSERIAL   PRIMARY KEY,
    task_id    BIGINT      NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    content    TEXT        NOT NULL,
    done       BOOLEAN     NOT NULL DEFAULT FALSE,
    position   INT         NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_checklist_task ON checklist_items (task_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE checklist_items;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN recurrence, DROP COLUMN parent_id;
-- +goose StatementEnd
