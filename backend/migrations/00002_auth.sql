-- +goose Up
-- +goose StatementBegin
CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    email         TEXT        NOT NULL UNIQUE,
    password_hash TEXT        NOT NULL,
    full_name     TEXT        NOT NULL DEFAULT '',
    email_verified BOOLEAN    NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE otp_codes (
    id         BIGSERIAL   PRIMARY KEY,
    email      TEXT        NOT NULL,
    code_hash  TEXT        NOT NULL,
    purpose    TEXT        NOT NULL, -- 'signup' | 'reset'
    expires_at TIMESTAMPTZ NOT NULL,
    consumed   BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_otp_email_purpose ON otp_codes (email, purpose);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE otp_codes;
DROP TABLE users;
-- +goose StatementEnd
