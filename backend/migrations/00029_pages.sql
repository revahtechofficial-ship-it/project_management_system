-- +goose Up
-- +goose StatementBegin
CREATE TABLE pages (
    id         BIGSERIAL   PRIMARY KEY,
    type       TEXT        NOT NULL DEFAULT 'doc',
    title      TEXT        NOT NULL DEFAULT '',
    icon       TEXT        NOT NULL DEFAULT '',
    body       TEXT        NOT NULL DEFAULT '',
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    updated_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_pages_type ON pages (type, updated_at DESC);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE pages;
-- +goose StatementEnd
