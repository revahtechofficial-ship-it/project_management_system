-- +goose Up
-- +goose StatementBegin
ALTER TABLE tasks
    ADD COLUMN priority TEXT   NOT NULL DEFAULT 'none',
    ADD COLUMN tags     TEXT[] NOT NULL DEFAULT '{}';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN tags, DROP COLUMN priority;
-- +goose StatementEnd
