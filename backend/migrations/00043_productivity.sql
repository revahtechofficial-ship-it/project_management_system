-- +goose Up
-- +goose StatementBegin
CREATE TABLE favorites (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind       TEXT        NOT NULL,
    item_id    BIGINT      NOT NULL,
    label      TEXT        NOT NULL DEFAULT '',
    route      TEXT        NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, kind, item_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_favorites_user ON favorites (user_id, created_at DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE saved_filters (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name       TEXT        NOT NULL DEFAULT '',
    config     TEXT        NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_saved_filters_user ON saved_filters (user_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE reminders (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    task_id    BIGINT      REFERENCES tasks (id) ON DELETE CASCADE,
    note       TEXT        NOT NULL DEFAULT '',
    remind_at  TIMESTAMPTZ NOT NULL,
    sent       BOOLEAN     NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_reminders_due ON reminders (remind_at) WHERE NOT sent;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE reminders;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE saved_filters;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE favorites;
-- +goose StatementEnd
