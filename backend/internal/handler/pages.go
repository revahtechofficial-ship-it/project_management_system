package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// PageHandler serves /api/v1/pages — collaborative Docs, Whiteboards and Forms.
// One table backs all three; the `type` field selects the editor on the client.
type PageHandler struct {
	q *db.Queries
}

// NewPageHandler wires the handler to the query layer.
func NewPageHandler(q *db.Queries) *PageHandler {
	return &PageHandler{q: q}
}

// Routes builds the sub-router mounted at /api/v1/pages.
func (h *PageHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{id}", h.get)
	r.Put("/{id}", h.update)
	r.Patch("/{id}/parent", h.setParent)
	r.Patch("/{id}/visibility", h.setVisibility)
	r.Get("/{id}/shares", h.listShares)
	r.Post("/{id}/shares", h.addShare)
	r.Delete("/{id}/shares/{userId}", h.removeShare)
	r.Delete("/{id}", h.delete)
	return r
}

type pageResponse struct {
	ID            int64      `json:"id"`
	Type          string     `json:"type"`
	Title         string     `json:"title"`
	Icon          string     `json:"icon"`
	Body          string     `json:"body"`
	ParentID      *int64     `json:"parent_id"`
	IsTemplate    bool       `json:"is_template"`
	Category      string     `json:"category"`
	OwnerID       *int64     `json:"owner_id"`
	OwnerName     string     `json:"owner_name"`
	ReviewAt      *time.Time `json:"review_at"`
	Visibility    string     `json:"visibility"`
	Access        string     `json:"access"`
	CanManage     bool       `json:"can_manage"`
	CreatedByName string     `json:"created_by_name"`
	UpdatedByName string     `json:"updated_by_name"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

type shareResponse struct {
	UserID     int64   `json:"user_id"`
	Permission string  `json:"permission"`
	FullName   string  `json:"full_name"`
	Email      string  `json:"email"`
	AvatarURL  *string `json:"avatar_url"`
}

// pageAccessLevel resolves the actor's access to a page: "edit", "view", or ""
// (no access). Workspace pages are editable by everyone; private pages are
// limited to the author, admins, and explicitly shared users.
func pageAccessLevel(actor *int64, isAdmin bool, createdBy *int64, visibility, myPermission string) string {
	if isAdmin {
		return "edit"
	}
	if actor != nil && createdBy != nil && *createdBy == *actor {
		return "edit"
	}
	if visibility == "workspace" {
		return "edit"
	}
	switch myPermission {
	case "edit":
		return "edit"
	case "view":
		return "view"
	}
	return ""
}

func pageFromList(p db.ListPagesRow, actor *int64, admin bool) pageResponse {
	owns := actor != nil && p.CreatedBy != nil && *p.CreatedBy == *actor
	return pageResponse{
		ID:            p.ID,
		Type:          p.Type,
		Title:         p.Title,
		Icon:          p.Icon,
		ParentID:      p.ParentID,
		IsTemplate:    p.IsTemplate,
		Category:      p.Category,
		OwnerID:       p.OwnerID,
		OwnerName:     p.OwnerName,
		ReviewAt:      tsPtr(p.ReviewAt),
		Visibility:    p.Visibility,
		Access:        pageAccessLevel(actor, admin, p.CreatedBy, p.Visibility, p.MyPermission),
		CanManage:     admin || owns,
		CreatedByName: p.CreatedByName,
		UpdatedByName: p.UpdatedByName,
		CreatedAt:     p.CreatedAt,
		UpdatedAt:     p.UpdatedAt,
	}
}

func pageFromGet(p db.GetPageRow, access string, canManage bool) pageResponse {
	return pageResponse{
		ID:            p.ID,
		Type:          p.Type,
		Title:         p.Title,
		Icon:          p.Icon,
		Body:          p.Body,
		ParentID:      p.ParentID,
		IsTemplate:    p.IsTemplate,
		Category:      p.Category,
		OwnerID:       p.OwnerID,
		OwnerName:     p.OwnerName,
		ReviewAt:      tsPtr(p.ReviewAt),
		Visibility:    p.Visibility,
		Access:        access,
		CanManage:     canManage,
		CreatedByName: p.CreatedByName,
		UpdatedByName: p.UpdatedByName,
		CreatedAt:     p.CreatedAt,
		UpdatedAt:     p.UpdatedAt,
	}
}

// access loads the actor's access level for a fetched page (one share lookup).
func (h *PageHandler) access(ctx context.Context, p db.GetPageRow) string {
	actor := actorOf(ctx)
	perm := ""
	if actor != nil {
		perm, _ = h.q.GetPageShare(ctx, db.GetPageShareParams{
			PageID: p.ID, UserID: *actor,
		})
	}
	return pageAccessLevel(actor, isAdmin(ctx), p.CreatedBy, p.Visibility, perm)
}

// canManage reports whether the actor may change a page's sharing (author or
// admin).
func (h *PageHandler) canManage(ctx context.Context, p db.GetPageRow) bool {
	actor := actorOf(ctx)
	owns := actor != nil && p.CreatedBy != nil && *p.CreatedBy == *actor
	return owns || isAdmin(ctx)
}

// normPageType keeps the type to the supported kinds, defaulting to doc.
func normPageType(t string) string {
	switch t {
	case "doc", "sop", "whiteboard", "form":
		return t
	default:
		return "doc"
	}
}

func (h *PageHandler) list(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	pageType := normPageType(r.URL.Query().Get("type"))
	isTemplate := r.URL.Query().Get("template") == "true"
	actor := actorOf(ctx)
	admin := isAdmin(ctx)
	rows, err := h.q.ListPages(ctx, db.ListPagesParams{
		Type:       pageType,
		IsTemplate: isTemplate,
		Actor:      actor,
		IsAdmin:    admin,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]pageResponse, 0, len(rows))
	for _, p := range rows {
		out = append(out, pageFromList(p, actor, admin))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *PageHandler) get(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	row, err := h.q.GetPage(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("page not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	access := h.access(r.Context(), row)
	if access == "" {
		writeError(w, http.StatusForbidden, errors.New("you don't have access to this page"))
		return
	}
	writeJSON(w, http.StatusOK, pageFromGet(row, access, h.canManage(r.Context(), row)))
}

type pageBody struct {
	Type       string  `json:"type"`
	Title      string  `json:"title"`
	Icon       string  `json:"icon"`
	Body       string  `json:"body"`
	ParentID   *int64  `json:"parent_id"`
	IsTemplate bool    `json:"is_template"`
	Category   string  `json:"category"`
	OwnerID    *int64  `json:"owner_id"`
	ReviewAt   *string `json:"review_at"`
}

func (h *PageHandler) create(w http.ResponseWriter, r *http.Request) {
	var b pageBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	review, err := parseDue(b.ReviewAt)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid review date"))
		return
	}
	actor := actorOf(r.Context())
	p, err := h.q.CreatePage(r.Context(), db.CreatePageParams{
		Type:       normPageType(b.Type),
		Title:      strings.TrimSpace(b.Title),
		Icon:       strings.TrimSpace(b.Icon),
		Body:       b.Body,
		ParentID:   b.ParentID,
		IsTemplate: b.IsTemplate,
		Category:   strings.TrimSpace(b.Category),
		OwnerID:    b.OwnerID,
		ReviewAt:   review,
		CreatedBy:  actor,
		UpdatedBy:  actor,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	// Reload with author names so the client gets a complete record.
	row, err := h.q.GetPage(r.Context(), p.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, pageFromGet(row, "edit", true))
}

func (h *PageHandler) update(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b pageBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	review, err := parseDue(b.ReviewAt)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid review date"))
		return
	}
	existing, err := h.q.GetPage(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("page not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if h.access(r.Context(), existing) != "edit" {
		writeError(w, http.StatusForbidden, errors.New("you can't edit this page"))
		return
	}
	if err := h.q.UpdatePage(r.Context(), db.UpdatePageParams{
		ID:        id,
		Title:     strings.TrimSpace(b.Title),
		Icon:      strings.TrimSpace(b.Icon),
		Body:      b.Body,
		Category:  strings.TrimSpace(b.Category),
		OwnerID:   b.OwnerID,
		ReviewAt:  review,
		UpdatedBy: actorOf(r.Context()),
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	row, err := h.q.GetPage(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, pageFromGet(row, "edit", h.canManage(r.Context(), row)))
}

type setParentBody struct {
	ParentID *int64 `json:"parent_id"`
}

func (h *PageHandler) setParent(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b setParentBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	// Guard against cycles: a page can't be its own parent, nor be moved under
	// one of its own descendants. Walk up the proposed parent's ancestor chain.
	if b.ParentID != nil {
		if *b.ParentID == id {
			writeError(w, http.StatusBadRequest, errors.New("a page cannot be its own parent"))
			return
		}
		cur := b.ParentID
		for hops := 0; cur != nil && hops < 100; hops++ {
			if *cur == id {
				writeError(w, http.StatusBadRequest, errors.New("cannot move a page under its own descendant"))
				return
			}
			row, err := h.q.GetPage(r.Context(), *cur)
			if err != nil {
				break
			}
			cur = row.ParentID
		}
	}
	if err := h.q.SetPageParent(r.Context(), db.SetPageParentParams{
		ID: id, ParentID: b.ParentID,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// loadManageable fetches the {id} page and confirms the actor may manage its
// sharing (author or admin), writing the error response if not.
func (h *PageHandler) loadManageable(w http.ResponseWriter, r *http.Request) (db.GetPageRow, bool) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return db.GetPageRow{}, false
	}
	row, err := h.q.GetPage(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("page not found"))
		return db.GetPageRow{}, false
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return db.GetPageRow{}, false
	}
	if !h.canManage(r.Context(), row) {
		writeError(w, http.StatusForbidden, errors.New("only the author or an admin can manage sharing"))
		return db.GetPageRow{}, false
	}
	return row, true
}

func (h *PageHandler) setVisibility(w http.ResponseWriter, r *http.Request) {
	row, ok := h.loadManageable(w, r)
	if !ok {
		return
	}
	var b struct {
		Visibility string `json:"visibility"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Visibility != "workspace" && b.Visibility != "private" {
		writeError(w, http.StatusBadRequest, errors.New("visibility must be workspace or private"))
		return
	}
	if err := h.q.SetPageVisibility(r.Context(), db.SetPageVisibilityParams{
		ID: row.ID, Visibility: b.Visibility,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *PageHandler) listShares(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	row, err := h.q.GetPage(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("page not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if h.access(r.Context(), row) == "" {
		writeError(w, http.StatusForbidden, errors.New("you don't have access to this page"))
		return
	}
	rows, err := h.q.ListPageShares(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]shareResponse, 0, len(rows))
	for _, s := range rows {
		out = append(out, shareResponse{
			UserID:     s.UserID,
			Permission: s.Permission,
			FullName:   s.FullName,
			Email:      s.Email,
			AvatarURL:  avatarURLPtr(s.Avatar),
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *PageHandler) addShare(w http.ResponseWriter, r *http.Request) {
	row, ok := h.loadManageable(w, r)
	if !ok {
		return
	}
	var b struct {
		UserID     int64  `json:"user_id"`
		Permission string `json:"permission"`
	}
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if b.Permission != "view" && b.Permission != "edit" {
		b.Permission = "view"
	}
	if b.UserID == 0 {
		writeError(w, http.StatusBadRequest, errors.New("a user is required"))
		return
	}
	if err := h.q.UpsertPageShare(r.Context(), db.UpsertPageShareParams{
		PageID: row.ID, UserID: b.UserID, Permission: b.Permission,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *PageHandler) removeShare(w http.ResponseWriter, r *http.Request) {
	row, ok := h.loadManageable(w, r)
	if !ok {
		return
	}
	target, err := strconv.ParseInt(chi.URLParam(r, "userId"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid user id"))
		return
	}
	if err := h.q.RemovePageShare(r.Context(), db.RemovePageShareParams{
		PageID: row.ID, UserID: target,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *PageHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	row, err := h.q.GetPage(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	// Only the page's creator or an admin may delete it.
	actor := actorOf(r.Context())
	owns := actor != nil && row.CreatedBy != nil && *row.CreatedBy == *actor
	if !owns && !isAdmin(r.Context()) {
		writeError(w, http.StatusForbidden, errors.New("only the author or an admin can delete this page"))
		return
	}
	if err := h.q.DeletePage(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
