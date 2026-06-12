-- +goose Up
-- +goose StatementBegin
CREATE TABLE attachments (
    id           BIGSERIAL   PRIMARY KEY,
    task_id      BIGINT      NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    uploader_id  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    filename     TEXT        NOT NULL,
    stored_name  TEXT        NOT NULL,
    content_type TEXT        NOT NULL DEFAULT '',
    size         BIGINT      NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_attachments_task ON attachments (task_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE attachments;
-- +goose StatementEnd
