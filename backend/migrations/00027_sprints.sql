-- +goose Up
-- +goose StatementBegin
CREATE TABLE sprints (
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT        NOT NULL,
    goal       TEXT        NOT NULL DEFAULT '',
    status     TEXT        NOT NULL DEFAULT 'planned', -- planned|active|completed
    start_date TIMESTAMPTZ,
    end_date   TIMESTAMPTZ,
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks ADD COLUMN sprint_id BIGINT REFERENCES sprints (id) ON DELETE SET NULL;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE tasks ADD COLUMN points INT NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN points;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN sprint_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP TABLE sprints;
-- +goose StatementEnd
