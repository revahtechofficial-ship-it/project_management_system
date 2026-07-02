-- +goose Up
-- +goose StatementBegin
CREATE TABLE approvals (
    id            BIGSERIAL   PRIMARY KEY,
    subject_type  TEXT        NOT NULL,
    subject_id    BIGINT      NOT NULL,
    subject_title TEXT        NOT NULL DEFAULT '',
    requester_id  BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    approver_id   BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status        TEXT        NOT NULL DEFAULT 'pending',
    note          TEXT        NOT NULL DEFAULT '',
    decided_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_approvals_approver ON approvals (approver_id, status);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_approvals_requester ON approvals (requester_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_approvals_subject ON approvals (subject_type, subject_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE approvals;
-- +goose StatementEnd
