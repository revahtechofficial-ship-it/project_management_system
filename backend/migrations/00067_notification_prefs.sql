-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN notification_prefs TEXT NOT NULL DEFAULT '{}';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN notification_prefs;
-- +goose StatementEnd
