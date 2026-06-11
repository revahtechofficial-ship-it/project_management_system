-- +goose Up
-- +goose StatementBegin
CREATE TABLE task_dependencies (
    id             BIGSERIAL   PRIMARY KEY,
    predecessor_id BIGINT      NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    successor_id   BIGINT      NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    type           TEXT        NOT NULL DEFAULT 'finish_to_start',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (predecessor_id, successor_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_dep_predecessor ON task_dependencies (predecessor_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_dep_successor ON task_dependencies (successor_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE task_dependencies;
-- +goose StatementEnd
