-- +goose Up
-- +goose StatementBegin
ALTER TABLE tasks
    ADD COLUMN start_date TIMESTAMPTZ,
    ADD COLUMN due_date   TIMESTAMPTZ;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN due_date, DROP COLUMN start_date;
-- +goose StatementEnd
