-- +goose Up
-- +goose StatementBegin
CREATE TABLE leave_requests (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type        TEXT        NOT NULL DEFAULT 'vacation',
    start_date  TIMESTAMPTZ NOT NULL,
    end_date    TIMESTAMPTZ NOT NULL,
    status      TEXT        NOT NULL DEFAULT 'pending',
    note        TEXT        NOT NULL DEFAULT '',
    approver_id BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    decided_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_leave_user ON leave_requests (user_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_leave_status ON leave_requests (status);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_leave_dates ON leave_requests (start_date, end_date);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE leave_requests;
-- +goose StatementEnd
