-- name: CreateConversation :one
INSERT INTO conversations (type, name, created_by)
VALUES (sqlc.arg(type), sqlc.arg(name), sqlc.narg(created_by))
RETURNING *;

-- name: AddConversationMember :exec
INSERT INTO conversation_members (conversation_id, user_id, role)
VALUES (sqlc.arg(conversation_id), sqlc.arg(user_id), sqlc.arg(role))
ON CONFLICT (conversation_id, user_id) DO NOTHING;

-- name: RemoveConversationMember :exec
DELETE FROM conversation_members
WHERE conversation_id = sqlc.arg(conversation_id)
  AND user_id = sqlc.arg(user_id);

-- name: RenameConversation :exec
UPDATE conversations SET name = sqlc.arg(name)
WHERE id = sqlc.arg(id);

-- name: GetConversationMemberRole :one
SELECT role FROM conversation_members
WHERE conversation_id = $1 AND user_id = $2;

-- name: ConversationMemberIDs :many
SELECT user_id FROM conversation_members
WHERE conversation_id = $1;

-- name: ListConversationMembers :many
SELECT cm.user_id, cm.role, cm.joined_at, u.full_name, u.email
FROM conversation_members cm
JOIN users u ON u.id = cm.user_id
WHERE cm.conversation_id = $1
ORDER BY u.full_name;

-- name: FindDMConversation :one
SELECT c.id
FROM conversations c
JOIN conversation_members a
    ON a.conversation_id = c.id AND a.user_id = sqlc.arg(user_a)
JOIN conversation_members b
    ON b.conversation_id = c.id AND b.user_id = sqlc.arg(user_b)
WHERE c.type = 'dm'
  AND (SELECT COUNT(*) FROM conversation_members m
       WHERE m.conversation_id = c.id) = 2
LIMIT 1;

-- name: CreateMessage :one
INSERT INTO messages (
    conversation_id, sender_id, kind, body,
    attachment_name, attachment_stored, attachment_type, attachment_size)
VALUES (
    sqlc.arg(conversation_id), sqlc.narg(sender_id), sqlc.arg(kind), sqlc.arg(body),
    sqlc.arg(attachment_name), sqlc.arg(attachment_stored),
    sqlc.arg(attachment_type), sqlc.arg(attachment_size))
RETURNING *;

-- name: GetMessageWithSender :one
SELECT m.*, u.full_name AS sender_name
FROM messages m
LEFT JOIN users u ON u.id = m.sender_id
WHERE m.id = $1;

-- name: ListMessages :many
SELECT m.*, u.full_name AS sender_name
FROM messages m
LEFT JOIN users u ON u.id = m.sender_id
WHERE m.conversation_id = sqlc.arg(conversation_id)
ORDER BY m.created_at DESC
LIMIT sqlc.arg(lim) OFFSET sqlc.arg(off);

-- name: MarkConversationRead :exec
UPDATE conversation_members SET last_read_at = now()
WHERE conversation_id = sqlc.arg(conversation_id)
  AND user_id = sqlc.arg(user_id);

-- name: DeleteMessage :exec
DELETE FROM messages WHERE id = $1;

-- name: UpdateMessageBody :exec
UPDATE messages SET body = $2, edited = TRUE WHERE id = $1;

-- name: AddReaction :exec
INSERT INTO message_reactions (message_id, user_id, emoji)
VALUES ($1, $2, $3)
ON CONFLICT DO NOTHING;

-- name: RemoveReaction :exec
DELETE FROM message_reactions
WHERE message_id = $1 AND user_id = $2 AND emoji = $3;

-- name: HasReaction :one
SELECT EXISTS (
    SELECT 1 FROM message_reactions
    WHERE message_id = $1 AND user_id = $2 AND emoji = $3
);

-- name: ListReactionsForConversation :many
SELECT r.message_id, r.emoji, r.user_id
FROM message_reactions r
JOIN messages m ON m.id = r.message_id
WHERE m.conversation_id = $1
ORDER BY r.created_at;

-- name: ListConversationsForUser :many
SELECT
    c.id,
    c.type,
    c.name,
    c.created_at,
    cm.last_read_at,
    COALESCE((SELECT m.body FROM messages m WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1), '')::text AS last_body,
    COALESCE((SELECT m.kind FROM messages m WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1), '')::text AS last_kind,
    COALESCE((SELECT m.created_at FROM messages m WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1), c.created_at) AS last_at,
    (SELECT m.sender_id FROM messages m WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1) AS last_sender_id,
    COALESCE((
        SELECT COUNT(*) FROM messages m2
        WHERE m2.conversation_id = c.id
          AND (cm.last_read_at IS NULL OR m2.created_at > cm.last_read_at)
          AND m2.sender_id IS DISTINCT FROM sqlc.arg(user_id)
    ), 0)::int AS unread_count,
    COALESCE((SELECT cm2.user_id FROM conversation_members cm2
        WHERE cm2.conversation_id = c.id
          AND cm2.user_id <> sqlc.arg(user_id)
          AND c.type = 'dm'
        LIMIT 1), 0)::bigint AS other_user_id,
    COALESCE((SELECT u.full_name FROM conversation_members cm2
        JOIN users u ON u.id = cm2.user_id
        WHERE cm2.conversation_id = c.id
          AND cm2.user_id <> sqlc.arg(user_id)
          AND c.type = 'dm'
        LIMIT 1), '')::text AS other_user_name
FROM conversation_members cm
JOIN conversations c ON c.id = cm.conversation_id
WHERE cm.user_id = sqlc.arg(user_id)
ORDER BY last_at DESC, c.created_at DESC;
