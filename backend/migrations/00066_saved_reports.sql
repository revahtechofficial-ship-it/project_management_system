-- +goose Up
-- +goose StatementBegin
CREATE TABLE saved_reports (
    id         BIGSERIAL   PRIMARY KEY,
    name       TEXT        NOT NULL DEFAULT '',
    config     TEXT        NOT NULL DEFAULT '{}',
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE saved_reports;
-- +goose StatementEnd
