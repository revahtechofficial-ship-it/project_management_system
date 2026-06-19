-- +goose Up
-- +goose StatementBegin
CREATE TABLE automation_rules (
    id          BIGSERIAL   PRIMARY KEY,
    name        TEXT        NOT NULL DEFAULT '',
    enabled     BOOLEAN     NOT NULL DEFAULT true,
    trigger     TEXT        NOT NULL DEFAULT 'task_created',
    conditions  TEXT        NOT NULL DEFAULT '[]',
    actions     TEXT        NOT NULL DEFAULT '[]',
    created_by  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_automation_rules_trigger ON automation_rules (trigger, enabled);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE automation_rules;
-- +goose StatementEnd
