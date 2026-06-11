// Package account implements custom email/password authentication: users in
// Postgres, bcrypt password hashing, a password policy, 6-digit email OTPs, and
// app-issued JWT sessions.
package account

import (
	"unicode"

	"golang.org/x/crypto/bcrypt"
)

// ValidationError is a user-facing input error (maps to HTTP 400).
type ValidationError struct{ Msg string }

func (e ValidationError) Error() string { return e.Msg }

// HashPassword returns a bcrypt hash of the plaintext password.
func HashPassword(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	return string(b), err
}

// CheckPassword reports whether plain matches the bcrypt hash.
func CheckPassword(hash, plain string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)) == nil
}

// ValidatePassword enforces the policy: >= 8 chars and at least one uppercase,
// one lowercase, one digit, and one special character.
func ValidatePassword(pw string) error {
	if len(pw) < 8 {
		return ValidationError{"Password must be at least 8 characters."}
	}
	var upper, lower, digit, special bool
	for _, r := range pw {
		switch {
		case unicode.IsUpper(r):
			upper = true
		case unicode.IsLower(r):
			lower = true
		case unicode.IsDigit(r):
			digit = true
		case unicode.IsPunct(r) || unicode.IsSymbol(r):
			special = true
		}
	}
	switch {
	case !upper:
		return ValidationError{"Password must contain an uppercase letter."}
	case !lower:
		return ValidationError{"Password must contain a lowercase letter."}
	case !digit:
		return ValidationError{"Password must contain a number."}
	case !special:
		return ValidationError{"Password must contain a special character."}
	}
	return nil
}
