-- +goose Up
-- +goose StatementBegin
CREATE TABLE dashboards (
    id         BIGSERIAL   PRIMARY KEY,
    name       TEXT        NOT NULL DEFAULT '',
    owner_id   BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    visibility TEXT        NOT NULL DEFAULT 'workspace',
    widgets    TEXT        NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE dashboards;
-- +goose StatementEnd
