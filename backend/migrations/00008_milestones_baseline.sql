-- +goose Up
-- +goose StatementBegin
ALTER TABLE tasks
    ADD COLUMN baseline_start TIMESTAMPTZ,
    ADD COLUMN baseline_due   TIMESTAMPTZ;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE milestones (
    id         BIGSERIAL   PRIMARY KEY,
    project_id BIGINT      REFERENCES projects (id) ON DELETE CASCADE,
    name       TEXT        NOT NULL,
    due_date   TIMESTAMPTZ NOT NULL,
    done       BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_milestones_project ON milestones (project_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE milestones;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN baseline_due, DROP COLUMN baseline_start;
-- +goose StatementEnd
