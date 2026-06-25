package handler

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

// auditLog records a security/administration event, attributing it to the
// authenticated actor. Best-effort: failures never block the request.
func auditLog(ctx context.Context, q *db.Queries, action, target, detail string) {
	_ = q.CreateAuditLog(ctx, db.CreateAuditLogParams{
		ActorID:   actorOf(ctx),
		ActorName: actorName(ctx),
		Action:    action,
		Target:    target,
		Detail:    detail,
	})
}

// GuestReadOnly blocks mutating requests for users with the "guest" role; they
// get read-only access to the workspace. It must run after authentication so
// the role is available in the context.
func GuestReadOnly(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if c, ok := account.FromContext(r.Context()); ok && c.Role == "guest" {
			switch r.Method {
			case http.MethodGet, http.MethodHead, http.MethodOptions:
			default:
				writeError(w, http.StatusForbidden,
					errors.New("guests have read-only access"))
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

// AdminHandler serves /api/v1/admin — the admin console: member access
// management, the workspace security settings, and the audit log.
type AdminHandler struct {
	q *db.Queries
}

// NewAdminHandler wires the handler to the query layer.
func NewAdminHandler(q *db.Queries) *AdminHandler {
	return &AdminHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/admin (all admin-only).
func (h *AdminHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/members", h.members)
	r.Patch("/members/{id}/role", h.setRole)
	r.Patch("/members/{id}/active", h.setActive)
	r.Get("/audit-log", h.auditLogList)
	r.Get("/settings", h.getSettings)
	r.Put("/settings", h.updateSettings)
	return r
}

type adminMemberResponse struct {
	ID               int64     `json:"id"`
	Email            string    `json:"email"`
	FullName         string    `json:"full_name"`
	Role             string    `json:"role"`
	AvatarURL        *string   `json:"avatar_url"`
	IsActive         bool      `json:"is_active"`
	TwoFactorEnabled bool      `json:"two_factor_enabled"`
	CreatedAt        time.Time `json:"created_at"`
}

func (h *AdminHandler) members(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	rows, err := h.q.ListAdminMembers(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]adminMemberResponse, 0, len(rows))
	for _, m := range rows {
		out = append(out, adminMemberResponse{
			ID:               m.ID,
			Email:            m.Email,
			FullName:         m.FullName,
			Role:             m.Role,
			AvatarURL:        avatarURLPtr(m.Avatar),
			IsActive:         m.IsActive,
			TwoFactorEnabled: m.TwoFactorEnabled,
			CreatedAt:        m.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *AdminHandler) setRole(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b struct {
		Role string `json:"role"`
	}
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Role != "admin" && b.Role != "member" && b.Role != "guest" {
		writeError(w, http.StatusBadRequest,
			errors.New("role must be 'admin', 'member' or 'guest'"))
		return
	}
	target, err := h.q.GetUserByID(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("user not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if target.Role == "owner" {
		writeError(w, http.StatusForbidden,
			errors.New("the workspace owner's role cannot be changed"))
		return
	}
	if _, err := h.q.SetUserRole(r.Context(),
		db.SetUserRoleParams{ID: id, Role: b.Role}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	auditLog(r.Context(), h.q, "role.changed", target.Email,
		"set role to "+b.Role)
	writeJSON(w, http.StatusOK, map[string]any{"id": id, "role": b.Role})
}

func (h *AdminHandler) setActive(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b struct {
		Active bool `json:"active"`
	}
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	target, err := h.q.GetUserByID(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("user not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if target.Role == "owner" && !b.Active {
		writeError(w, http.StatusForbidden,
			errors.New("the workspace owner cannot be deactivated"))
		return
	}
	if _, err := h.q.SetUserActive(r.Context(),
		db.SetUserActiveParams{ID: id, IsActive: b.Active}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	action := "user.deactivated"
	if b.Active {
		action = "user.activated"
	}
	auditLog(r.Context(), h.q, action, target.Email, "")
	writeJSON(w, http.StatusOK, map[string]any{"id": id, "is_active": b.Active})
}

type auditEntryResponse struct {
	ID        int64     `json:"id"`
	ActorName string    `json:"actor_name"`
	Action    string    `json:"action"`
	Target    string    `json:"target"`
	Detail    string    `json:"detail"`
	CreatedAt time.Time `json:"created_at"`
}

func (h *AdminHandler) auditLogList(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	rows, err := h.q.ListAuditLog(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]auditEntryResponse, 0, len(rows))
	for _, a := range rows {
		out = append(out, auditEntryResponse{
			ID:        a.ID,
			ActorName: a.ActorName,
			Action:    a.Action,
			Target:    a.Target,
			Detail:    a.Detail,
			CreatedAt: a.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type settingsResponse struct {
	Name           string `json:"name"`
	AllowedDomains string `json:"allowed_domains"`
	Require2FA     bool   `json:"require_2fa"`
	SessionHours   int32  `json:"session_hours"`
	SSOConfigured  bool   `json:"sso_configured"`
}

func (h *AdminHandler) getSettings(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	s, err := h.q.GetWorkspaceSettings(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, settingsResponse{
		Name:           s.Name,
		AllowedDomains: s.AllowedDomains,
		Require2FA:     s.Require2fa,
		SessionHours:   s.SessionHours,
		SSOConfigured:  ssoConfigured,
	})
}

func (h *AdminHandler) updateSettings(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b struct {
		Name           string `json:"name"`
		AllowedDomains string `json:"allowed_domains"`
		Require2FA     bool   `json:"require_2fa"`
		SessionHours   int32  `json:"session_hours"`
	}
	if err := decode(r, &b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.SessionHours < 1 {
		b.SessionHours = 24
	}
	if err := h.q.UpdateWorkspaceSettings(r.Context(),
		db.UpdateWorkspaceSettingsParams{
			Name:           strings.TrimSpace(b.Name),
			AllowedDomains: strings.TrimSpace(b.AllowedDomains),
			Require2fa:     b.Require2FA,
			SessionHours:   b.SessionHours,
		}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	auditLog(r.Context(), h.q, "settings.updated", "workspace", "")
	w.WriteHeader(http.StatusNoContent)
}

// ssoConfigured is set at startup from the OIDC issuer config so the admin UI
// can show whether SSO is wired up.
var ssoConfigured bool

// SetSSOConfigured records whether an OIDC issuer is configured (called once
// from main during wiring).
func SetSSOConfigured(v bool) { ssoConfigured = v }
