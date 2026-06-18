-- +goose Up
-- +goose StatementBegin
CREATE TABLE task_assignees (
    task_id BIGINT NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, user_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_task_assignees_user ON task_assignees (user_id);
-- +goose StatementEnd

-- Seed the join table from the existing single-assignee column so nothing is
-- lost. `assignee_id` stays as the denormalized "primary" assignee.
-- +goose StatementBegin
INSERT INTO task_assignees (task_id, user_id)
SELECT id, assignee_id FROM tasks WHERE assignee_id IS NOT NULL
ON CONFLICT DO NOTHING;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE task_assignees;
-- +goose StatementEnd
