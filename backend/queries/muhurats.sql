-- name: ListMuhurats :many
SELECT * FROM muhurats
WHERE muhurat_date >= sqlc.arg(from_date)
  AND muhurat_date <= sqlc.arg(to_date)
ORDER BY muhurat_date, start_time NULLS FIRST, id;

-- name: CreateMuhurat :one
INSERT INTO muhurats (muhurat_date, kind, start_time, end_time, note_en,
                      note_ne, source)
VALUES (sqlc.arg(muhurat_date), sqlc.arg(kind), sqlc.narg(start_time),
        sqlc.narg(end_time), sqlc.arg(note_en), sqlc.arg(note_ne),
        sqlc.arg(source))
RETURNING *;

-- name: DeleteMuhurat :exec
DELETE FROM muhurats WHERE id = $1;
