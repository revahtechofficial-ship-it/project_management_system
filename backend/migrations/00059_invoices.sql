-- +goose Up
-- +goose StatementBegin
CREATE SEQUENCE invoice_number_seq START 1001;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE invoices (
    id           BIGSERIAL   PRIMARY KEY,
    number       TEXT        NOT NULL UNIQUE,
    project_id   BIGINT      REFERENCES projects (id) ON DELETE SET NULL,
    client_name  TEXT        NOT NULL DEFAULT '',
    client_email TEXT        NOT NULL DEFAULT '',
    status       TEXT        NOT NULL DEFAULT 'draft',
    issue_date   DATE,
    due_date     DATE,
    notes        TEXT        NOT NULL DEFAULT '',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE invoice_lines (
    id               BIGSERIAL PRIMARY KEY,
    invoice_id       BIGINT    NOT NULL REFERENCES invoices (id) ON DELETE CASCADE,
    description      TEXT      NOT NULL DEFAULT '',
    quantity_minutes INT       NOT NULL DEFAULT 0,
    rate_cents       BIGINT    NOT NULL DEFAULT 0,
    amount_cents     BIGINT    NOT NULL DEFAULT 0,
    sort             INT       NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_invoice_lines_invoice ON invoice_lines (invoice_id, sort);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE time_entries
    ADD COLUMN invoice_id BIGINT REFERENCES invoices (id) ON DELETE SET NULL;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE time_entries DROP COLUMN invoice_id;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE invoice_lines;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE invoices;
-- +goose StatementEnd

-- +goose StatementBegin
DROP SEQUENCE invoice_number_seq;
-- +goose StatementEnd
