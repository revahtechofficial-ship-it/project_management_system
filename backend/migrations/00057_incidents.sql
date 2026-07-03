-- +goose Up
-- +goose StatementBegin
CREATE TABLE incidents (
    id          BIGSERIAL   PRIMARY KEY,
    title       TEXT        NOT NULL DEFAULT '',
    description TEXT        NOT NULL DEFAULT '',
    kind        TEXT        NOT NULL DEFAULT 'bug',
    severity    TEXT        NOT NULL DEFAULT 'medium',
    status      TEXT        NOT NULL DEFAULT 'open',
    project_id  BIGINT      REFERENCES projects (id) ON DELETE SET NULL,
    assignee_id BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    reporter_id BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    component   TEXT        NOT NULL DEFAULT '',
    resolved_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_incidents_status ON incidents (status);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_incidents_severity ON incidents (severity);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE incidents;
-- +goose StatementEnd
