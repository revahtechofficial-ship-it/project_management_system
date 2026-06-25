-- +goose Up
-- +goose StatementBegin
ALTER TABLE comments
    ADD COLUMN parent_id BIGINT REFERENCES comments (id) ON DELETE CASCADE;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_comments_parent ON comments (parent_id);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE conversations
    ADD COLUMN visibility TEXT NOT NULL DEFAULT 'private';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE conversations DROP COLUMN visibility;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX idx_comments_parent;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE comments DROP COLUMN parent_id;
-- +goose StatementEnd
