-- +goose Up
-- +goose StatementBegin
CREATE TABLE project_templates (
    id           BIGSERIAL PRIMARY KEY,
    name         TEXT        NOT NULL,
    project_name TEXT        NOT NULL DEFAULT '',
    description  TEXT        NOT NULL DEFAULT '',
    status       TEXT        NOT NULL DEFAULT 'active',
    created_by   BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE project_templates;
-- +goose StatementEnd
