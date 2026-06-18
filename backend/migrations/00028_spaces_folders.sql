-- +goose Up
-- +goose StatementBegin
CREATE TABLE spaces (
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT        NOT NULL,
    color      TEXT        NOT NULL DEFAULT '#6366f1',
    position   INT         NOT NULL DEFAULT 0,
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE folders (
    id         BIGSERIAL PRIMARY KEY,
    space_id   BIGINT      NOT NULL REFERENCES spaces (id) ON DELETE CASCADE,
    name       TEXT        NOT NULL,
    position   INT         NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- Projects are the "lists" of the hierarchy: a project sits directly in a
-- space, or inside a folder, or stays uncategorized (both null).
-- +goose StatementBegin
ALTER TABLE projects ADD COLUMN space_id BIGINT REFERENCES spaces (id) ON DELETE SET NULL;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE projects ADD COLUMN folder_id BIGINT REFERENCES folders (id) ON DELETE SET NULL;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE projects DROP COLUMN folder_id;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE projects DROP COLUMN space_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP TABLE folders;
-- +goose StatementEnd
-- +goose StatementBegin
DROP TABLE spaces;
-- +goose StatementEnd
