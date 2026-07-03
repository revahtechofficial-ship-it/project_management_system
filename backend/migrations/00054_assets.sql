-- +goose Up
-- +goose StatementBegin
CREATE TABLE assets (
    id           BIGSERIAL   PRIMARY KEY,
    name         TEXT        NOT NULL DEFAULT '',
    kind         TEXT        NOT NULL DEFAULT 'hardware',
    status       TEXT        NOT NULL DEFAULT 'available',
    identifier   TEXT        NOT NULL DEFAULT '',
    vendor       TEXT        NOT NULL DEFAULT '',
    assignee_id  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    cost_cents   BIGINT      NOT NULL DEFAULT 0,
    purchased_on DATE,
    expires_on   DATE,
    notes        TEXT        NOT NULL DEFAULT '',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_assets_status ON assets (status);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_assets_expires ON assets (expires_on);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE assets;
-- +goose StatementEnd
