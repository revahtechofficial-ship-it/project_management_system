-- +goose Up
-- +goose StatementBegin
CREATE TABLE project_budgets (
    id                BIGSERIAL   PRIMARY KEY,
    project_id        BIGINT      NOT NULL UNIQUE
                                  REFERENCES projects (id) ON DELETE CASCADE,
    amount_cents      BIGINT      NOT NULL DEFAULT 0,
    hourly_rate_cents BIGINT      NOT NULL DEFAULT 0,
    notes             TEXT        NOT NULL DEFAULT '',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE project_budgets;
-- +goose StatementEnd
