-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN status TEXT NOT NULL DEFAULT 'active';
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users ADD COLUMN status_message TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users ADD COLUMN last_seen_at TIMESTAMPTZ;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN last_seen_at;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users DROP COLUMN status_message;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users DROP COLUMN status;
-- +goose StatementEnd
