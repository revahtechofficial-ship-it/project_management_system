-- +goose Up
-- +goose StatementBegin
CREATE TABLE page_versions (
    id         BIGSERIAL   PRIMARY KEY,
    page_id    BIGINT      NOT NULL REFERENCES pages (id) ON DELETE CASCADE,
    title      TEXT        NOT NULL DEFAULT '',
    body       TEXT        NOT NULL DEFAULT '',
    edited_by  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    edited_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_page_versions_page ON page_versions (page_id, created_at DESC);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE page_versions;
-- +goose StatementEnd
