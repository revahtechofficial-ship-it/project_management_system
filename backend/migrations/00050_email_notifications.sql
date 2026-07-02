-- +goose Up
-- +goose StatementBegin
ALTER TABLE users
    ADD COLUMN email_notifications BOOLEAN NOT NULL DEFAULT true;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN email_notifications;
-- +goose StatementEnd
