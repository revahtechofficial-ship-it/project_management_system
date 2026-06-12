package handler

import (
	"context"
	"errors"
	"net/http"

	"github.com/revah-tech/revahms/backend/internal/account"
)

// isAdmin reports whether the authenticated caller is an owner or admin.
func isAdmin(ctx context.Context) bool {
	c, ok := account.FromContext(ctx)
	return ok && (c.Role == "owner" || c.Role == "admin")
}

// requireAdmin writes a 403 and returns false when the caller is not an
// owner/admin. Mutating admin-only handlers gate on it.
func requireAdmin(w http.ResponseWriter, r *http.Request) bool {
	if !isAdmin(r.Context()) {
		writeError(w, http.StatusForbidden,
			errors.New("admin access required"))
		return false
	}
	return true
}
