-- name: ListRepos :many
SELECT r.*,
       COALESCE(p.name, '')::text AS project_name,
       COALESCE((
           SELECT COUNT(*) FROM git_commits c WHERE c.repo_id = r.id
       ), 0)::bigint AS commit_count,
       (
           SELECT MAX(c.committed_at) FROM git_commits c WHERE c.repo_id = r.id
       ) AS last_commit_at
FROM git_repos r
LEFT JOIN projects p ON p.id = r.project_id
ORDER BY r.name, r.id;

-- name: CreateRepo :one
INSERT INTO git_repos (name, provider, url, default_branch, project_id,
                       webhook_token)
VALUES (sqlc.arg(name), sqlc.arg(provider), sqlc.arg(url),
        sqlc.arg(default_branch), sqlc.arg(project_id),
        sqlc.arg(webhook_token))
RETURNING *;

-- name: DeleteRepo :exec
DELETE FROM git_repos WHERE id = $1;

-- name: GetRepoByToken :one
SELECT * FROM git_repos WHERE webhook_token = $1;

-- name: InsertCommit :exec
INSERT INTO git_commits (repo_id, sha, message, author_name, author_email,
                         url, branch, task_ref, committed_at)
VALUES (sqlc.arg(repo_id), sqlc.arg(sha), sqlc.arg(message),
        sqlc.arg(author_name), sqlc.arg(author_email), sqlc.arg(url),
        sqlc.arg(branch), sqlc.arg(task_ref), sqlc.arg(committed_at))
ON CONFLICT (repo_id, sha) DO NOTHING;

-- name: ListCommits :many
SELECT c.*, r.name AS repo_name,
       COALESCE(t.title, '')::text AS task_title
FROM git_commits c
JOIN git_repos r ON r.id = c.repo_id
LEFT JOIN tasks t ON t.id = c.task_ref
ORDER BY c.committed_at DESC
LIMIT 200;
