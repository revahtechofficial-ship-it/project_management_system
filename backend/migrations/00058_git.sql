-- +goose Up
-- +goose StatementBegin
CREATE TABLE git_repos (
    id             BIGSERIAL   PRIMARY KEY,
    name           TEXT        NOT NULL DEFAULT '',
    provider       TEXT        NOT NULL DEFAULT 'github',
    url            TEXT        NOT NULL DEFAULT '',
    default_branch TEXT        NOT NULL DEFAULT 'main',
    project_id     BIGINT      REFERENCES projects (id) ON DELETE SET NULL,
    webhook_token  TEXT        NOT NULL UNIQUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE git_commits (
    id           BIGSERIAL   PRIMARY KEY,
    repo_id      BIGINT      NOT NULL REFERENCES git_repos (id) ON DELETE CASCADE,
    sha          TEXT        NOT NULL,
    message      TEXT        NOT NULL DEFAULT '',
    author_name  TEXT        NOT NULL DEFAULT '',
    author_email TEXT        NOT NULL DEFAULT '',
    url          TEXT        NOT NULL DEFAULT '',
    branch       TEXT        NOT NULL DEFAULT '',
    task_ref     BIGINT,
    committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (repo_id, sha)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_git_commits_repo ON git_commits (repo_id, committed_at DESC);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE git_commits;
DROP TABLE git_repos;
-- +goose StatementEnd
