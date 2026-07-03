-- +goose Up
-- +goose StatementBegin
CREATE TABLE expenses (
    id           BIGSERIAL   PRIMARY KEY,
    user_id      BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    project_id   BIGINT      REFERENCES projects (id) ON DELETE SET NULL,
    category     TEXT        NOT NULL DEFAULT 'other',
    amount_cents BIGINT      NOT NULL DEFAULT 0,
    spent_on     DATE,
    description  TEXT        NOT NULL DEFAULT '',
    merchant     TEXT        NOT NULL DEFAULT '',
    receipt_url  TEXT        NOT NULL DEFAULT '',
    status       TEXT        NOT NULL DEFAULT 'pending',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_expenses_status ON expenses (status);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_expenses_user ON expenses (user_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE expenses;
-- +goose StatementEnd
