-- +goose Up
-- +goose StatementBegin
CREATE TABLE custom_fields (
    id         BIGSERIAL   PRIMARY KEY,
    name       TEXT        NOT NULL,
    field_type TEXT        NOT NULL DEFAULT 'text',
    options    TEXT[]      NOT NULL DEFAULT '{}',
    position   INT         NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE task_field_values (
    task_id  BIGINT NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    field_id BIGINT NOT NULL REFERENCES custom_fields (id) ON DELETE CASCADE,
    value    TEXT   NOT NULL DEFAULT '',
    PRIMARY KEY (task_id, field_id)
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE task_field_values;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE custom_fields;
-- +goose StatementEnd
