-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN phone TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN job_title TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN department TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN location TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN bio TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN bio;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN location;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN department;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN job_title;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN phone;
-- +goose StatementEnd
