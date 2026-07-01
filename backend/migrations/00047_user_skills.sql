-- +goose Up
-- +goose StatementBegin
CREATE TABLE user_skills (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    skill      TEXT        NOT NULL,
    level      INT         NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, skill)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_user_skills_user ON user_skills (user_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_user_skills_skill ON user_skills (skill);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE user_skills;
-- +goose StatementEnd
