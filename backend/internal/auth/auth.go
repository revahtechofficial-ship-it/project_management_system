// Package auth verifies Keycloak (OIDC) bearer tokens for protected routes.
package auth

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/coreos/go-oidc/v3/oidc"
)

type ctxKey int

const claimsKey ctxKey = iota

// Claims is the subset of OIDC token claims the app uses.
type Claims struct {
	Subject  string `json:"sub"`
	Username string `json:"preferred_username"`
	Email    string `json:"email"`
	Name     string `json:"name"`
}

// Verifier validates bearer tokens against an OIDC issuer's signing keys.
type Verifier struct {
	verifier *oidc.IDTokenVerifier
}

// NewVerifier discovers the issuer (a network call) and builds a token verifier.
func NewVerifier(ctx context.Context, issuer string) (*Verifier, error) {
	provider, err := oidc.NewProvider(ctx, issuer)
	if err != nil {
		return nil, err
	}
	// Resource-server verification: signature + issuer + expiry. Audience is
	// skipped because Keycloak access tokens default to aud=account; add an
	// audience mapper to the realm to tighten this later.
	v := provider.Verifier(&oidc.Config{SkipClientIDCheck: true})
	return &Verifier{verifier: v}, nil
}

// Middleware verifies the Bearer token and stores the Claims in the context.
func (v *Verifier) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, err := bearerToken(r)
		if err != nil {
			writeUnauthorized(w, err.Error())
			return
		}
		token, err := v.verifier.Verify(r.Context(), raw)
		if err != nil {
			writeUnauthorized(w, "invalid token")
			return
		}
		var claims Claims
		if err := token.Claims(&claims); err != nil {
			writeUnauthorized(w, "cannot parse token claims")
			return
		}
		ctx := context.WithValue(r.Context(), claimsKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// FromContext returns the Claims injected by Middleware, if present.
func FromContext(ctx context.Context) (Claims, bool) {
	claims, ok := ctx.Value(claimsKey).(Claims)
	return claims, ok
}

func bearerToken(r *http.Request) (string, error) {
	header := r.Header.Get("Authorization")
	if header == "" {
		return "", errors.New("missing Authorization header")
	}
	parts := strings.SplitN(header, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", errors.New("malformed Authorization header")
	}
	return parts[1], nil
}

func writeUnauthorized(w http.ResponseWriter, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
