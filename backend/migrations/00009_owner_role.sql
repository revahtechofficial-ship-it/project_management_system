-- +goose Up
-- +goose StatementBegin
UPDATE users SET role = 'owner'
WHERE id = (SELECT id FROM users ORDER BY id ASC LIMIT 1)
  AND NOT EXISTS (SELECT 1 FROM users WHERE role = 'owner');
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
UPDATE users SET role = 'member' WHERE role = 'owner';
-- +goose StatementEnd
