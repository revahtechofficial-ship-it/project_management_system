-- +goose Up
-- +goose StatementBegin
CREATE TABLE objectives (
    id          BIGSERIAL   PRIMARY KEY,
    title       TEXT        NOT NULL DEFAULT '',
    description TEXT        NOT NULL DEFAULT '',
    owner_id    BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    parent_id   BIGINT      REFERENCES objectives (id) ON DELETE SET NULL,
    period      TEXT        NOT NULL DEFAULT '',
    status      TEXT        NOT NULL DEFAULT 'active',
    created_by  BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE key_results (
    id            BIGSERIAL        PRIMARY KEY,
    objective_id  BIGINT           NOT NULL REFERENCES objectives (id) ON DELETE CASCADE,
    title         TEXT             NOT NULL DEFAULT '',
    start_value   DOUBLE PRECISION NOT NULL DEFAULT 0,
    current_value DOUBLE PRECISION NOT NULL DEFAULT 0,
    target_value  DOUBLE PRECISION NOT NULL DEFAULT 100,
    unit          TEXT             NOT NULL DEFAULT '',
    position      INT              NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ      NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_key_results_objective ON key_results (objective_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE key_results;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE objectives;
-- +goose StatementEnd
