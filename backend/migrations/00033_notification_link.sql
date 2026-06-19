-- +goose Up
-- +goose StatementBegin
ALTER TABLE notifications ADD COLUMN link TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE notifications DROP COLUMN link;
-- +goose StatementEnd
