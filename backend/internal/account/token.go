package account

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type ctxKey int

const claimsKey ctxKey = iota

// Claims is the authenticated user carried in the app's JWT / request context.
type Claims struct {
	UserID int64
	Email  string
	Name   string
	Role   string
}

// Tokens issues and verifies the app's own HS256 JWT sessions.
type Tokens struct {
	secret []byte
}

// NewTokens builds a token signer/verifier from a shared secret.
func NewTokens(secret string) *Tokens { return &Tokens{secret: []byte(secret)} }

// Issue returns a signed JWT for the given claims, valid for ttl.
func (t *Tokens) Issue(c Claims, ttl time.Duration) (string, error) {
	now := time.Now()
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"uid":   c.UserID,
		"email": c.Email,
		"name":  c.Name,
		"role":  c.Role,
		"iat":   now.Unix(),
		"exp":   now.Add(ttl).Unix(),
	})
	return tok.SignedString(t.secret)
}

func (t *Tokens) parse(raw string) (Claims, error) {
	tok, err := jwt.Parse(raw, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return t.secret, nil
	})
	if err != nil || !tok.Valid {
		return Claims{}, errors.New("invalid token")
	}
	mc, ok := tok.Claims.(jwt.MapClaims)
	if !ok {
		return Claims{}, errors.New("invalid claims")
	}
	uid, _ := mc["uid"].(float64)
	email, _ := mc["email"].(string)
	name, _ := mc["name"].(string)
	role, _ := mc["role"].(string)
	return Claims{UserID: int64(uid), Email: email, Name: name, Role: role}, nil
}

// Middleware verifies the Bearer JWT and injects Claims into the context.
func (t *Tokens) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		parts := strings.SplitN(r.Header.Get("Authorization"), " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			unauthorized(w)
			return
		}
		claims, err := t.parse(parts[1])
		if err != nil {
			unauthorized(w)
			return
		}
		ctx := context.WithValue(r.Context(), claimsKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// MiddlewareWithQuery verifies the Bearer JWT from the Authorization header or,
// failing that, a `token` query parameter. Used for browser file downloads,
// where a plain navigation can't set an Authorization header.
func (t *Tokens) MiddlewareWithQuery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := ""
		parts := strings.SplitN(r.Header.Get("Authorization"), " ", 2)
		if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
			raw = parts[1]
		}
		if raw == "" {
			raw = r.URL.Query().Get("token")
		}
		claims, err := t.parse(raw)
		if err != nil {
			unauthorized(w)
			return
		}
		ctx := context.WithValue(r.Context(), claimsKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// FromContext returns the Claims injected by Middleware.
func FromContext(ctx context.Context) (Claims, bool) {
	c, ok := ctx.Value(claimsKey).(Claims)
	return c, ok
}

func unauthorized(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_, _ = w.Write([]byte(`{"error":"unauthorized"}`))
}
