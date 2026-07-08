-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN calendar_token TEXT;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE UNIQUE INDEX idx_users_calendar_token
    ON users (calendar_token) WHERE calendar_token IS NOT NULL;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX idx_users_calendar_token;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users DROP COLUMN calendar_token;
-- +goose StatementEnd
