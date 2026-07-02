package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// AccountHandler serves the custom email/password auth endpoints.
type AccountHandler struct {
	svc *account.Service
}

// NewAccountHandler wires the handler to the account service.
func NewAccountHandler(svc *account.Service) *AccountHandler {
	return &AccountHandler{svc: svc}
}

func normEmail(e string) string { return strings.ToLower(strings.TrimSpace(e)) }

// userResponse is the JSON shape the client expects for the signed-in user,
// used by login, /me, and the profile endpoints so every payload is identical.
func userResponse(u db.User) map[string]any {
	return map[string]any{
		"id":                  u.ID,
		"email":               u.Email,
		"name":                u.FullName,
		"role":                u.Role,
		"avatar_url":          avatarURLPtr(u.Avatar),
		"phone":               u.Phone,
		"job_title":           u.JobTitle,
		"department":          u.Department,
		"location":            u.Location,
		"bio":                 u.Bio,
		"two_factor_enabled":  u.TwoFactorEnabled,
		"email_notifications": u.EmailNotifications,
	}
}

func decode(r *http.Request, v any) error {
	return json.NewDecoder(r.Body).Decode(v)
}

// accountError maps service errors to HTTP responses.
func (h *AccountHandler) accountError(w http.ResponseWriter, err error) {
	var ve account.ValidationError
	switch {
	case errors.As(err, &ve):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, account.ErrEmailTaken):
		writeError(w, http.StatusConflict, err)
	case errors.Is(err, account.ErrInvalidCredentials):
		writeError(w, http.StatusUnauthorized, err)
	case errors.Is(err, account.ErrEmailNotVerified):
		writeError(w, http.StatusForbidden, err)
	case errors.Is(err, account.ErrInvalidOTP):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, account.ErrWrongPassword):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, account.ErrAccountDisabled):
		writeError(w, http.StatusForbidden, err)
	case errors.Is(err, account.ErrDomainNotAllowed):
		writeError(w, http.StatusForbidden, err)
	default:
		writeError(w, http.StatusInternalServerError, errors.New("something went wrong"))
	}
}

type registerReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	FullName string `json:"full_name"`
}

// Register creates an unverified account and emails a signup code.
func (h *AccountHandler) Register(w http.ResponseWriter, r *http.Request) {
	var b registerReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	email := normEmail(b.Email)
	if email == "" {
		writeError(w, http.StatusBadRequest, errors.New("email is required"))
		return
	}
	if err := h.svc.Register(r.Context(), email, b.Password, strings.TrimSpace(b.FullName)); err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{
		"message": "Account created. We emailed a 6-digit code to verify your account.",
	})
}

type otpReq struct {
	Email string `json:"email"`
	Code  string `json:"code"`
}

// VerifyEmail confirms a signup code; the user must then log in.
func (h *AccountHandler) VerifyEmail(w http.ResponseWriter, r *http.Request) {
	var b otpReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.svc.VerifyEmail(r.Context(), normEmail(b.Email), strings.TrimSpace(b.Code)); err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"message": "Email verified. Please sign in.",
	})
}

type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// Login returns a session JWT and basic profile on success.
func (h *AccountHandler) Login(w http.ResponseWriter, r *http.Request) {
	var b loginReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	token, claims, err := h.svc.Login(r.Context(), normEmail(b.Email), b.Password)
	if errors.Is(err, account.ErrTwoFactorRequired) {
		// Password was correct; a code was emailed. The client must now call
		// /auth/verify-login-otp with it.
		writeJSON(w, http.StatusOK, map[string]any{
			"requires_2fa": true,
			"email":        normEmail(b.Email),
		})
		return
	}
	if err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, h.loginPayload(r, token, claims))
}

func (h *AccountHandler) loginPayload(r *http.Request, token string,
	claims account.Claims) map[string]any {
	var user map[string]any
	if u, uerr := h.svc.GetUser(r.Context(), claims.UserID); uerr == nil {
		user = userResponse(u)
	} else {
		user = claimsResponse(claims)
	}
	return map[string]any{"token": token, "user": user}
}

type verifyLoginReq struct {
	Email string `json:"email"`
	Code  string `json:"code"`
}

// VerifyLoginOTP completes a two-factor login and returns the session JWT.
func (h *AccountHandler) VerifyLoginOTP(w http.ResponseWriter, r *http.Request) {
	var b verifyLoginReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	token, claims, err := h.svc.VerifyLoginOTP(r.Context(), normEmail(b.Email), b.Code)
	if err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, h.loginPayload(r, token, claims))
}

type twoFactorReq struct {
	Enabled bool `json:"enabled"`
}

// SetTwoFactor toggles email two-factor auth for the authenticated user.
func (h *AccountHandler) SetTwoFactor(w http.ResponseWriter, r *http.Request) {
	claims, ok := account.FromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b twoFactorReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.svc.SetTwoFactor(r.Context(), claims.UserID, b.Enabled); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"two_factor_enabled": b.Enabled})
}

// SetEmailNotifications toggles whether the user also receives their in-app
// notifications by email.
func (h *AccountHandler) SetEmailNotifications(w http.ResponseWriter, r *http.Request) {
	claims, ok := account.FromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	var b twoFactorReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.svc.SetEmailNotifications(r.Context(), claims.UserID, b.Enabled); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"email_notifications": b.Enabled})
}

// claimsResponse is a minimal user payload built from the JWT when the full row
// can't be loaded (keeps the same keys as userResponse for client safety).
func claimsResponse(c account.Claims) map[string]any {
	return map[string]any{
		"id": c.UserID, "email": c.Email, "name": c.Name, "role": c.Role,
		"avatar_url": nil, "phone": "", "job_title": "",
		"department": "", "location": "", "bio": "",
		"two_factor_enabled": false, "email_notifications": true,
	}
}

type emailReq struct {
	Email   string `json:"email"`
	Purpose string `json:"purpose"`
}

// ForgotPassword emails a reset code (always 200, to avoid email enumeration).
func (h *AccountHandler) ForgotPassword(w http.ResponseWriter, r *http.Request) {
	var b emailReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.svc.ForgotPassword(r.Context(), normEmail(b.Email)); err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"message": "If that email has an account, we sent a 6-digit reset code.",
	})
}

type resetReq struct {
	Email       string `json:"email"`
	Code        string `json:"code"`
	NewPassword string `json:"new_password"`
}

// ResetPassword sets a new password via a reset code; the user must then log in.
func (h *AccountHandler) ResetPassword(w http.ResponseWriter, r *http.Request) {
	var b resetReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.svc.ResetPassword(r.Context(), normEmail(b.Email), strings.TrimSpace(b.Code), b.NewPassword); err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"message": "Password updated. Please sign in with your new password.",
	})
}

// ResendOTP re-issues a signup or reset code.
func (h *AccountHandler) ResendOTP(w http.ResponseWriter, r *http.Request) {
	var b emailReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.svc.ResendOTP(r.Context(), normEmail(b.Email), b.Purpose); err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "A new code is on its way."})
}

// Me returns the current user (behind the app JWT middleware).
func (h *AccountHandler) Me(w http.ResponseWriter, r *http.Request) {
	claims, ok := account.FromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("not authenticated"))
		return
	}
	if u, uerr := h.svc.GetUser(r.Context(), claims.UserID); uerr == nil {
		writeJSON(w, http.StatusOK, userResponse(u))
		return
	}
	writeJSON(w, http.StatusOK, claimsResponse(claims))
}

type updateProfileReq struct {
	FullName   string `json:"full_name"`
	Phone      string `json:"phone"`
	JobTitle   string `json:"job_title"`
	Department string `json:"department"`
	Location   string `json:"location"`
	Bio        string `json:"bio"`
}

// UpdateProfile saves the authenticated user's editable profile fields
// (JWT-protected) and returns the refreshed user.
func (h *AccountHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	claims, ok := account.FromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("not authenticated"))
		return
	}
	var b updateProfileReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.FullName)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	u, err := h.svc.UpdateProfile(r.Context(), claims.UserID, account.ProfileInput{
		FullName:   name,
		Phone:      strings.TrimSpace(b.Phone),
		JobTitle:   strings.TrimSpace(b.JobTitle),
		Department: strings.TrimSpace(b.Department),
		Location:   strings.TrimSpace(b.Location),
		Bio:        strings.TrimSpace(b.Bio),
	})
	if err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, userResponse(u))
}

type changePasswordReq struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

// ChangePassword updates the authenticated user's password (JWT-protected).
func (h *AccountHandler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	claims, ok := account.FromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("not authenticated"))
		return
	}
	var b changePasswordReq
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := h.svc.ChangePassword(r.Context(), claims.UserID, b.CurrentPassword, b.NewPassword); err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"message": "Password updated successfully.",
	})
}
