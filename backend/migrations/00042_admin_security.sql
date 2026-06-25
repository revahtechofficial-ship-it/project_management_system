-- +goose Up
-- +goose StatementBegin
ALTER TABLE users
    ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users
    ADD COLUMN two_factor_enabled BOOLEAN NOT NULL DEFAULT false;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE audit_log (
    id         BIGSERIAL   PRIMARY KEY,
    actor_id   BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    actor_name TEXT        NOT NULL DEFAULT '',
    action     TEXT        NOT NULL,
    target     TEXT        NOT NULL DEFAULT '',
    detail     TEXT        NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_audit_log_created ON audit_log (created_at DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE workspace_settings (
    id              INT         PRIMARY KEY DEFAULT 1,
    name            TEXT        NOT NULL DEFAULT 'Revah',
    allowed_domains TEXT        NOT NULL DEFAULT '',
    require_2fa     BOOLEAN     NOT NULL DEFAULT false,
    session_hours   INT         NOT NULL DEFAULT 24,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workspace_settings_singleton CHECK (id = 1)
);
-- +goose StatementEnd

-- +goose StatementBegin
INSERT INTO workspace_settings (id) VALUES (1) ON CONFLICT DO NOTHING;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE workspace_settings;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE audit_log;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users DROP COLUMN two_factor_enabled;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE users DROP COLUMN is_active;
-- +goose StatementEnd
