-- +goose Up
-- +goose StatementBegin
CREATE TABLE member_capacity (
    user_id      BIGINT      PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    weekly_hours INT         NOT NULL DEFAULT 40,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE availability (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    start_date DATE        NOT NULL,
    end_date   DATE        NOT NULL,
    kind       TEXT        NOT NULL DEFAULT 'other',
    note       TEXT        NOT NULL DEFAULT '',
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_availability_dates ON availability (start_date, end_date);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE availability;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE member_capacity;
-- +goose StatementEnd
