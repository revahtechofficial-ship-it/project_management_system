-- +goose Up
-- +goose StatementBegin
ALTER TABLE tasks ADD COLUMN completed_at TIMESTAMPTZ;
-- +goose StatementEnd

-- +goose StatementBegin
-- Backfill: approximate historical completion times from the last update so
-- cycle/lead-time metrics have data immediately.
UPDATE tasks SET completed_at = updated_at WHERE done = true;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE tasks DROP COLUMN completed_at;
-- +goose StatementEnd
