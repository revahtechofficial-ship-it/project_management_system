package handler

import (
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// avatarURLPtr maps a stored avatar filename to the public URL the client uses,
// or nil when the user has no avatar. The URL is content-addressed by the random
// stored name, so it changes on every upload (cache-busts automatically).
func avatarURLPtr(stored string) *string {
	if stored == "" {
		return nil
	}
	u := "/api/v1/avatars/" + stored
	return &u
}

// AvatarHandler stores and serves user profile photos.
type AvatarHandler struct {
	q   *db.Queries
	dir string
}

// NewAvatarHandler wires the handler to the query layer and storage directory.
func NewAvatarHandler(q *db.Queries, dir string) *AvatarHandler {
	return &AvatarHandler{q: q, dir: dir}
}

// Upload stores the authenticated user's new profile photo and returns the
// refreshed user (so the client can update its session).
func (h *AvatarHandler) Upload(w http.ResponseWriter, r *http.Request) {
	actor, ok := chatActor(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("unauthenticated"))
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes)
	if err := r.ParseMultipartForm(maxUploadBytes); err != nil {
		writeError(w, http.StatusBadRequest, errors.New("file too large (max 25MB)"))
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("an image file is required"))
		return
	}
	defer file.Close()
	if !strings.HasPrefix(header.Header.Get("Content-Type"), "image/") {
		writeError(w, http.StatusBadRequest, errors.New("only image files are allowed"))
		return
	}

	if err := os.MkdirAll(h.dir, 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	stored := randomHex(16) + filepath.Ext(header.Filename)
	dst, err := os.Create(filepath.Join(h.dir, stored))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	_, copyErr := io.Copy(dst, file)
	closeErr := dst.Close()
	if copyErr != nil || closeErr != nil {
		writeError(w, http.StatusInternalServerError, errors.New("could not store image"))
		return
	}

	old, _ := h.q.GetUserByID(r.Context(), actor)
	u, err := h.q.SetUserAvatar(r.Context(), db.SetUserAvatarParams{
		ID: actor, Avatar: stored,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if old.Avatar != "" && old.Avatar != stored {
		_ = os.Remove(filepath.Join(h.dir, old.Avatar))
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id":         u.ID,
		"email":      u.Email,
		"name":       u.FullName,
		"role":       u.Role,
		"avatar_url": avatarURLPtr(u.Avatar),
	})
}

// Serve streams a profile photo by its stored name. Avatars are not sensitive,
// so this endpoint is public; the random, content-addressed name is the key.
func (h *AvatarHandler) Serve(w http.ResponseWriter, r *http.Request) {
	name := filepath.Base(chi.URLParam(r, "name"))
	if name == "" || name == "." || name == string(filepath.Separator) {
		http.NotFound(w, r)
		return
	}
	path := filepath.Join(h.dir, name)
	if _, err := os.Stat(path); err != nil {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	http.ServeFile(w, r, path)
}
