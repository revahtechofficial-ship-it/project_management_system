-- +goose Up
-- +goose StatementBegin
CREATE TABLE project_shares (
    token      TEXT        PRIMARY KEY,
    project_id BIGINT      NOT NULL UNIQUE REFERENCES projects (id) ON DELETE CASCADE,
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE project_shares;
-- +goose StatementEnd
