-- name: CreateOTP :one
INSERT INTO otp_codes (email, code_hash, purpose, expires_at)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: GetLatestOTP :one
SELECT * FROM otp_codes
WHERE email = $1 AND purpose = $2 AND consumed = FALSE
ORDER BY created_at DESC
LIMIT 1;

-- name: ConsumeOTP :exec
UPDATE otp_codes
SET consumed = TRUE
WHERE id = $1;

-- name: DeleteOTPs :exec
DELETE FROM otp_codes
WHERE email = $1 AND purpose = $2;
