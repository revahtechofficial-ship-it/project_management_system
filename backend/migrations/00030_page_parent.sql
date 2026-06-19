-- +goose Up
-- +goose StatementBegin
ALTER TABLE pages
    ADD COLUMN parent_id BIGINT REFERENCES pages (id) ON DELETE SET NULL;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_pages_parent ON pages (parent_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE pages DROP COLUMN parent_id;
-- +goose StatementEnd
