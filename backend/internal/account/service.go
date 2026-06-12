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
	ErrWrongPassword      = errors.New("current password is incorrect")
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
	u, err := s.q.CreateUser(ctx, db.CreateUserParams{
		Email: em, PasswordHash: hash, FullName: fullName,
	})
	if err != nil {
		return err
	}
	// The very first account to register owns the workspace.
	if n, err := s.q.CountUsers(ctx); err == nil && n == 1 {
		_, _ = s.q.SetUserRole(ctx, db.SetUserRoleParams{ID: u.ID, Role: "owner"})
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

// UpdateProfile changes the user's display name and returns the updated row.
func (s *Service) UpdateProfile(ctx context.Context, userID int64, fullName string) (db.User, error) {
	return s.q.UpdateUserName(ctx, db.UpdateUserNameParams{ID: userID, FullName: fullName})
}

// GetUser returns a user by id (used to surface fields not carried in the JWT,
// such as the avatar).
func (s *Service) GetUser(ctx context.Context, userID int64) (db.User, error) {
	return s.q.GetUserByID(ctx, userID)
}

// ChangePassword verifies the current password, then sets a new (policy-checked)
// one for the authenticated user.
func (s *Service) ChangePassword(ctx context.Context, userID int64, current, newPassword string) error {
	u, err := s.q.GetUserByID(ctx, userID)
	if err != nil {
		return ErrInvalidCredentials
	}
	if !CheckPassword(u.PasswordHash, current) {
		return ErrWrongPassword
	}
	if err := ValidatePassword(newPassword); err != nil {
		return err
	}
	hash, err := HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.q.UpdatePassword(ctx, db.UpdatePasswordParams{Email: u.Email, PasswordHash: hash})
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
	c := Claims{UserID: u.ID, Email: u.Email, Name: u.FullName, Role: u.Role}
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
