-- +goose Up
-- +goose StatementBegin
CREATE TABLE task_statuses (
    id        BIGSERIAL PRIMARY KEY,
    key       TEXT    NOT NULL UNIQUE,
    label     TEXT    NOT NULL,
    color     TEXT    NOT NULL DEFAULT '#64748b',
    position  INT     NOT NULL DEFAULT 0,
    protected BOOLEAN NOT NULL DEFAULT FALSE
);
-- +goose StatementEnd

-- Seed the five built-in statuses. `todo` and `done` are protected from
-- deletion because the done-checkbox logic maps to those keys.
-- +goose StatementBegin
INSERT INTO task_statuses (key, label, color, position, protected) VALUES
    ('backlog',     'Backlog',     '#64748b', 0, FALSE),
    ('todo',        'To Do',       '#0ea5e9', 1, TRUE),
    ('in_progress', 'In Progress', '#6366f1', 2, FALSE),
    ('review',      'Review',      '#8b5cf6', 3, FALSE),
    ('done',        'Done',        '#22c55e', 4, TRUE);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE task_statuses;
-- +goose StatementEnd
