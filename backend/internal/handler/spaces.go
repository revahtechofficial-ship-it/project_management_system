package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// SpaceHandler serves /api/v1/spaces and the nested /folders — the project
// organization hierarchy (Space › Folder › Project). Writes are admin-only.
type SpaceHandler struct {
	q *db.Queries
}

// NewSpaceHandler wires the handler to the query layer.
func NewSpaceHandler(q *db.Queries) *SpaceHandler {
	return &SpaceHandler{q: q}
}

// Routes builds a sub-router for /api/v1/spaces (folders live under it).
func (h *SpaceHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.listSpaces)
	r.Post("/", h.createSpace)
	r.Put("/{id}", h.updateSpace)
	r.Delete("/{id}", h.deleteSpace)
	r.Get("/folders", h.listFolders)
	r.Post("/folders", h.createFolder)
	r.Put("/folders/{id}", h.updateFolder)
	r.Delete("/folders/{id}", h.deleteFolder)
	return r
}

type spaceResponse struct {
	ID       int64  `json:"id"`
	Name     string `json:"name"`
	Color    string `json:"color"`
	Position int32  `json:"position"`
}

func spaceFromModel(s db.Space) spaceResponse {
	return spaceResponse{ID: s.ID, Name: s.Name, Color: s.Color, Position: s.Position}
}

type folderResponse struct {
	ID       int64  `json:"id"`
	SpaceID  int64  `json:"space_id"`
	Name     string `json:"name"`
	Position int32  `json:"position"`
}

func folderFromModel(f db.Folder) folderResponse {
	return folderResponse{ID: f.ID, SpaceID: f.SpaceID, Name: f.Name, Position: f.Position}
}

func (h *SpaceHandler) listSpaces(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListSpaces(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]spaceResponse, 0, len(rows))
	for _, s := range rows {
		out = append(out, spaceFromModel(s))
	}
	writeJSON(w, http.StatusOK, out)
}

type spaceBody struct {
	Name  string `json:"name"`
	Color string `json:"color"`
}

func (h *SpaceHandler) createSpace(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b spaceBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a space name is required"))
		return
	}
	pos, err := h.q.MaxSpacePosition(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	s, err := h.q.CreateSpace(r.Context(), db.CreateSpaceParams{
		Name: name, Color: normColor(b.Color), Position: pos + 1,
		CreatedBy: actorOf(r.Context()),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, spaceFromModel(s))
}

func (h *SpaceHandler) updateSpace(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b spaceBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a space name is required"))
		return
	}
	s, err := h.q.UpdateSpace(r.Context(), db.UpdateSpaceParams{
		ID: id, Name: name, Color: normColor(b.Color),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, spaceFromModel(s))
}

func (h *SpaceHandler) deleteSpace(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteSpace(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *SpaceHandler) listFolders(w http.ResponseWriter, r *http.Request) {
	rows, err := h.q.ListFolders(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	out := make([]folderResponse, 0, len(rows))
	for _, f := range rows {
		out = append(out, folderFromModel(f))
	}
	writeJSON(w, http.StatusOK, out)
}

type folderBody struct {
	SpaceID int64  `json:"space_id"`
	Name    string `json:"name"`
}

func (h *SpaceHandler) createFolder(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var b folderBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" || b.SpaceID == 0 {
		writeError(w, http.StatusBadRequest, errors.New("a folder name and space are required"))
		return
	}
	pos, err := h.q.MaxFolderPosition(r.Context(), b.SpaceID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	f, err := h.q.CreateFolder(r.Context(), db.CreateFolderParams{
		SpaceID: b.SpaceID, Name: name, Position: pos + 1,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, folderFromModel(f))
}

func (h *SpaceHandler) updateFolder(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	var b folderBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	name := strings.TrimSpace(b.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, errors.New("a folder name is required"))
		return
	}
	f, err := h.q.UpdateFolder(r.Context(), db.UpdateFolderParams{ID: id, Name: name})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, folderFromModel(f))
}

func (h *SpaceHandler) deleteFolder(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	if err := h.q.DeleteFolder(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
