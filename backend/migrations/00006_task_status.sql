-- +goose Up
-- +goose StatementBegin
ALTER TABLE tasks ADD COLUMN status TEXT NOT NULL DEFAULT 'todo';
-- +goose StatementEnd

-- +goose StatementBegin
UPDATE tasks SET status = 'done' WHERE done = TRUE;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN status;
-- +goose StatementEnd
