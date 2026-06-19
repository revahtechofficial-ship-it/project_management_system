-- +goose Up
-- +goose StatementBegin
CREATE TABLE form_responses (
    id           BIGSERIAL   PRIMARY KEY,
    page_id      BIGINT      NOT NULL REFERENCES pages (id) ON DELETE CASCADE,
    submitted_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    answers      TEXT        NOT NULL DEFAULT '{}',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_form_responses_page ON form_responses (page_id, created_at DESC);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE form_responses;
-- +goose StatementEnd
