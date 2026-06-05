// Package migrations embeds the SQL migration files so they ship inside the
// compiled binary and can be applied by goose at startup (no external files
// required at deploy time). sqlc reads the .sql files directly and ignores this
// Go file.
package migrations

import "embed"

// FS holds every *.sql migration in this directory.
//
//go:embed *.sql
var FS embed.FS
