-- +goose Up
-- +goose StatementBegin
CREATE TABLE conversations (
    id         BIGSERIAL   PRIMARY KEY,
    type       TEXT        NOT NULL DEFAULT 'dm',
    name       TEXT        NOT NULL DEFAULT '',
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE conversation_members (
    conversation_id BIGINT      NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    user_id         BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role            TEXT        NOT NULL DEFAULT 'member',
    last_read_at    TIMESTAMPTZ,
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (conversation_id, user_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_conversation_members_user ON conversation_members (user_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE messages (
    id                BIGSERIAL   PRIMARY KEY,
    conversation_id   BIGINT      NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    sender_id         BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    kind              TEXT        NOT NULL DEFAULT 'text',
    body              TEXT        NOT NULL DEFAULT '',
    attachment_name   TEXT        NOT NULL DEFAULT '',
    attachment_stored TEXT        NOT NULL DEFAULT '',
    attachment_type   TEXT        NOT NULL DEFAULT '',
    attachment_size   BIGINT      NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_messages_conversation ON messages (conversation_id, created_at);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE messages;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE conversation_members;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE conversations;
-- +goose StatementEnd
