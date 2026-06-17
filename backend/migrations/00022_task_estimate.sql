-- +goose Up
-- +goose StatementBegin
ALTER TABLE tasks ADD COLUMN estimate_minutes INT NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN estimate_minutes;
-- +goose StatementEnd
