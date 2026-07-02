-- +goose Up
-- +goose StatementBegin
CREATE TABLE one_on_ones (
    id           BIGSERIAL   PRIMARY KEY,
    manager_id   BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    report_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    scheduled_at TIMESTAMPTZ NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_one_on_ones_manager ON one_on_ones (manager_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_one_on_ones_report ON one_on_ones (report_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE one_on_one_items (
    id         BIGSERIAL   PRIMARY KEY,
    meeting_id BIGINT      NOT NULL REFERENCES one_on_ones (id) ON DELETE CASCADE,
    author_id  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    kind       TEXT        NOT NULL DEFAULT 'agenda',
    body       TEXT        NOT NULL DEFAULT '',
    done       BOOLEAN     NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_1on1_items_meeting
    ON one_on_one_items (meeting_id, created_at);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE one_on_one_items;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE one_on_ones;
-- +goose StatementEnd
