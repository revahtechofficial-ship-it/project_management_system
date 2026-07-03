-- +goose Up
-- +goose StatementBegin
CREATE TABLE retro_items (
    id         BIGSERIAL   PRIMARY KEY,
    sprint_id  BIGINT      NOT NULL REFERENCES sprints (id) ON DELETE CASCADE,
    kind       TEXT        NOT NULL DEFAULT 'start',
    body       TEXT        NOT NULL DEFAULT '',
    author_id  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    done       BOOLEAN     NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_retro_sprint ON retro_items (sprint_id, created_at);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE retro_items;
-- +goose StatementEnd
