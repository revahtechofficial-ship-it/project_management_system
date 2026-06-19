-- +goose Up
-- +goose StatementBegin
ALTER TABLE pages
    ADD COLUMN is_template BOOLEAN     NOT NULL DEFAULT false,
    ADD COLUMN category    TEXT        NOT NULL DEFAULT '',
    ADD COLUMN owner_id    BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    ADD COLUMN review_at   TIMESTAMPTZ;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_pages_template ON pages (type, is_template);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE pages
    DROP COLUMN is_template,
    DROP COLUMN category,
    DROP COLUMN owner_id,
    DROP COLUMN review_at;
-- +goose StatementEnd
