-- +goose Up
-- +goose StatementBegin
CREATE TABLE api_keys (
    id           BIGSERIAL   PRIMARY KEY,
    user_id      BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name         TEXT        NOT NULL DEFAULT '',
    token_hash   TEXT        NOT NULL,
    prefix       TEXT        NOT NULL DEFAULT '',
    last_used_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE UNIQUE INDEX idx_api_keys_hash ON api_keys (token_hash);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_api_keys_user ON api_keys (user_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE webhooks (
    id         BIGSERIAL   PRIMARY KEY,
    url        TEXT        NOT NULL,
    secret     TEXT        NOT NULL DEFAULT '',
    events     TEXT        NOT NULL DEFAULT '[]',
    active     BOOLEAN     NOT NULL DEFAULT true,
    provider   TEXT        NOT NULL DEFAULT 'custom',
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE integrations (
    provider   TEXT        PRIMARY KEY,
    connected  BOOLEAN     NOT NULL DEFAULT false,
    config     TEXT        NOT NULL DEFAULT '{}',
    updated_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE integrations;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE webhooks;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE api_keys;
-- +goose StatementEnd
