-- +goose Up
-- +goose StatementBegin
ALTER TABLE pages
    ADD COLUMN visibility TEXT NOT NULL DEFAULT 'workspace';
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE page_shares (
    page_id    BIGINT      NOT NULL REFERENCES pages (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    permission TEXT        NOT NULL DEFAULT 'view',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (page_id, user_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_page_shares_user ON page_shares (user_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE page_shares;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE pages DROP COLUMN visibility;
-- +goose StatementEnd
