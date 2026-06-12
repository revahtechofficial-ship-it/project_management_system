-- +goose Up
-- +goose StatementBegin
CREATE TABLE message_reactions (
    message_id BIGINT      NOT NULL REFERENCES messages (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    emoji      TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, user_id, emoji)
);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE messages ADD COLUMN edited BOOLEAN NOT NULL DEFAULT FALSE;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE messages DROP COLUMN edited;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE message_reactions;
-- +goose StatementEnd
