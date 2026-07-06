-- +goose Up
-- +goose StatementBegin
CREATE TABLE page_links (
    id             BIGSERIAL   PRIMARY KEY,
    source_page_id BIGINT      NOT NULL REFERENCES pages (id) ON DELETE CASCADE,
    target_page_id BIGINT      NOT NULL REFERENCES pages (id) ON DELETE CASCADE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (source_page_id, target_page_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_page_links_target ON page_links (target_page_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE page_links;
-- +goose StatementEnd
