package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/revah-tech/revahms/backend/internal/account"
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
	if err != nil {
		h.accountError(w, err)
		return
	}
	var avatar *string
	if u, uerr := h.svc.GetUser(r.Context(), claims.UserID); uerr == nil {
		avatar = avatarURLPtr(u.Avatar)
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token": token,
		"user": map[string]any{
			"id":         claims.UserID,
			"email":      claims.Email,
			"name":       claims.Name,
			"role":       claims.Role,
			"avatar_url": avatar,
		},
	})
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
	var avatar *string
	if u, uerr := h.svc.GetUser(r.Context(), claims.UserID); uerr == nil {
		avatar = avatarURLPtr(u.Avatar)
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id": claims.UserID, "email": claims.Email, "name": claims.Name,
		"role": claims.Role, "avatar_url": avatar,
	})
}

type updateProfileReq struct {
	FullName string `json:"full_name"`
}

// UpdateProfile changes the authenticated user's display name (JWT-protected).
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
	u, err := h.svc.UpdateProfile(r.Context(), claims.UserID, name)
	if err != nil {
		h.accountError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id": u.ID, "email": u.Email, "name": u.FullName, "role": u.Role,
		"avatar_url": avatarURLPtr(u.Avatar),
	})
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
