package account

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
	"github.com/revah-tech/revahms/backend/internal/email"
)

// Sentinel errors mapped to HTTP statuses by the handler.
var (
	ErrEmailTaken         = errors.New("an account with this email already exists")
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrEmailNotVerified   = errors.New("please verify your email before signing in")
	ErrInvalidOTP         = errors.New("invalid or expired code")
)

const (
	otpTTL     = 10 * time.Minute
	sessionTTL = 24 * time.Hour
)

// Service is the custom-auth business logic.
type Service struct {
	q      *db.Queries
	tokens *Tokens
	mail   *email.Sender
}

// NewService wires the service to the DB, token signer, and email sender.
func NewService(q *db.Queries, tokens *Tokens, mail *email.Sender) *Service {
	return &Service{q: q, tokens: tokens, mail: mail}
}

// Register creates an unverified account and emails a signup OTP. The caller is
// NOT logged in — they must verify, then sign in.
func (s *Service) Register(ctx context.Context, em, password, fullName string) error {
	if err := ValidatePassword(password); err != nil {
		return err
	}
	exists, err := s.q.EmailExists(ctx, em)
	if err != nil {
		return err
	}
	if exists {
		return ErrEmailTaken
	}
	hash, err := HashPassword(password)
	if err != nil {
		return err
	}
	if _, err := s.q.CreateUser(ctx, db.CreateUserParams{
		Email: em, PasswordHash: hash, FullName: fullName,
	}); err != nil {
		return err
	}
	return s.issueOTP(ctx, em, "signup")
}

// VerifyEmail consumes a signup OTP and marks the account verified.
func (s *Service) VerifyEmail(ctx context.Context, em, code string) error {
	if err := s.checkOTP(ctx, em, "signup", code); err != nil {
		return err
	}
	return s.q.MarkEmailVerified(ctx, em)
}

// Login validates credentials and returns a session JWT + claims.
func (s *Service) Login(ctx context.Context, em, password string) (string, Claims, error) {
	u, err := s.q.GetUserByEmail(ctx, em)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", Claims{}, ErrInvalidCredentials
		}
		return "", Claims{}, err
	}
	if !CheckPassword(u.PasswordHash, password) {
		return "", Claims{}, ErrInvalidCredentials
	}
	if !u.EmailVerified {
		return "", Claims{}, ErrEmailNotVerified
	}
	c := Claims{UserID: u.ID, Email: u.Email, Name: u.FullName}
	tok, err := s.tokens.Issue(c, sessionTTL)
	if err != nil {
		return "", Claims{}, err
	}
	return tok, c, nil
}

// ForgotPassword emails a reset OTP if the account exists. It always returns nil
// for unknown emails (no account enumeration).
func (s *Service) ForgotPassword(ctx context.Context, em string) error {
	exists, err := s.q.EmailExists(ctx, em)
	if err != nil {
		return err
	}
	if !exists {
		return nil
	}
	return s.issueOTP(ctx, em, "reset")
}

// ResetPassword consumes a reset OTP and sets a new (policy-checked) password.
func (s *Service) ResetPassword(ctx context.Context, em, code, newPassword string) error {
	if err := ValidatePassword(newPassword); err != nil {
		return err
	}
	if err := s.checkOTP(ctx, em, "reset", code); err != nil {
		return err
	}
	hash, err := HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.q.UpdatePassword(ctx, db.UpdatePasswordParams{Email: em, PasswordHash: hash})
}

// ResendOTP re-issues a code for the given purpose ("signup" | "reset").
func (s *Service) ResendOTP(ctx context.Context, em, purpose string) error {
	if purpose != "signup" && purpose != "reset" {
		return ValidationError{"invalid purpose"}
	}
	return s.issueOTP(ctx, em, purpose)
}

func (s *Service) issueOTP(ctx context.Context, em, purpose string) error {
	code, err := GenerateOTP()
	if err != nil {
		return err
	}
	_ = s.q.DeleteOTPs(ctx, db.DeleteOTPsParams{Email: em, Purpose: purpose})
	if _, err := s.q.CreateOTP(ctx, db.CreateOTPParams{
		Email:     em,
		CodeHash:  HashOTP(code),
		Purpose:   purpose,
		ExpiresAt: time.Now().Add(otpTTL),
	}); err != nil {
		return err
	}
	return s.mail.SendOTP(em, code, purpose)
}

func (s *Service) checkOTP(ctx context.Context, em, purpose, code string) error {
	row, err := s.q.GetLatestOTP(ctx, db.GetLatestOTPParams{Email: em, Purpose: purpose})
	if err != nil {
		return ErrInvalidOTP
	}
	if row.Consumed || time.Now().After(row.ExpiresAt) || row.CodeHash != HashOTP(code) {
		return ErrInvalidOTP
	}
	return s.q.ConsumeOTP(ctx, row.ID)
}
