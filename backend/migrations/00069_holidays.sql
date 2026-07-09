-- +goose Up
-- +goose StatementBegin
CREATE TABLE holidays (
    id           BIGSERIAL   PRIMARY KEY,
    holiday_date DATE        NOT NULL,
    name_en      TEXT        NOT NULL DEFAULT '',
    name_ne      TEXT        NOT NULL DEFAULT '',
    is_public    BOOLEAN     NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_holidays_date ON holidays (holiday_date);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE UNIQUE INDEX idx_holidays_unique ON holidays (holiday_date, name_en);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE holidays;
-- +goose StatementEnd
