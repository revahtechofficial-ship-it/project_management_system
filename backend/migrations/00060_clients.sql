-- +goose Up
-- +goose StatementBegin
CREATE TABLE clients (
    id           BIGSERIAL   PRIMARY KEY,
    name         TEXT        NOT NULL DEFAULT '',
    company      TEXT        NOT NULL DEFAULT '',
    email        TEXT        NOT NULL DEFAULT '',
    portal_token TEXT        NOT NULL UNIQUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE projects
    ADD COLUMN client_id BIGINT REFERENCES clients (id) ON DELETE SET NULL;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_projects_client ON projects (client_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE projects DROP COLUMN client_id;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE clients;
-- +goose StatementEnd
