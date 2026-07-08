-- +goose Up
-- +goose StatementBegin
CREATE TABLE checklist_templates (
    id         BIGSERIAL   PRIMARY KEY,
    name       TEXT        NOT NULL DEFAULT '',
    category   TEXT        NOT NULL DEFAULT '',
    items      TEXT        NOT NULL DEFAULT '[]',
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE checklist_templates;
-- +goose StatementEnd
