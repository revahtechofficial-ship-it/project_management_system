-- name: ListAllSkills :many
SELECT s.id, s.user_id, s.skill, s.level,
       u.full_name AS user_name, u.avatar
FROM user_skills s
JOIN users u ON u.id = s.user_id
ORDER BY u.full_name, s.skill;

-- name: ListMySkills :many
SELECT * FROM user_skills WHERE user_id = $1 ORDER BY skill;

-- name: UpsertSkill :one
INSERT INTO user_skills (user_id, skill, level)
VALUES (sqlc.arg(user_id), sqlc.arg(skill), sqlc.arg(level))
ON CONFLICT (user_id, skill) DO UPDATE
    SET level = EXCLUDED.level
RETURNING *;

-- name: DeleteSkill :exec
DELETE FROM user_skills WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id);
