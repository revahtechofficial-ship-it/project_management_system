package handler

import (
	"errors"
	"net/http"

	"github.com/revah-tech/nexax/backend/internal/auth"
)

// Me returns the authenticated caller's OIDC claims. It sits behind the auth
// middleware, so reaching it means the token has already been verified.
func Me(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.FromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("not authenticated"))
		return
	}
	writeJSON(w, http.StatusOK, claims)
}
