-- +goose Up
-- +goose StatementBegin
ALTER TABLE conversations ADD COLUMN avatar TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE conversations DROP COLUMN avatar;
-- +goose StatementEnd
