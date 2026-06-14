-- +goose Up
-- +goose StatementBegin
ALTER TABLE messages
    ADD COLUMN reply_to_id BIGINT REFERENCES messages (id) ON DELETE SET NULL;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE messages ADD COLUMN pinned BOOLEAN NOT NULL DEFAULT FALSE;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE messages ADD COLUMN forwarded BOOLEAN NOT NULL DEFAULT FALSE;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE messages DROP COLUMN forwarded;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE messages DROP COLUMN pinned;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE messages DROP COLUMN reply_to_id;
-- +goose StatementEnd
