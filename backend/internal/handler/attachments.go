package handler

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/revah-tech/revahms/backend/internal/account"
	"github.com/revah-tech/revahms/backend/internal/db"
)

const (
	maxUploadBytes  = 100 << 20 // 100 MiB total per upload
	maxUploadMemory = 16 << 20  // buffered in memory; the rest spills to a temp file
)

// attachmentResponse is the JSON shape exposed to clients — it deliberately
// omits the on-disk stored_name.
type attachmentResponse struct {
	ID           int64     `json:"id"`
	TaskID       int64     `json:"task_id"`
	UploaderID   *int64    `json:"uploader_id"`
	UploaderName *string   `json:"uploader_name"`
	Filename     string    `json:"filename"`
	ContentType  string    `json:"content_type"`
	Size         int64     `json:"size"`
	CreatedAt    time.Time `json:"created_at"`
}

func (h *TaskHandler) listAttachments(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	rows, err := h.q.ListAttachments(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, rows)
}

func (h *TaskHandler) uploadAttachment(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes+(1<<20))
	if err := r.ParseMultipartForm(maxUploadMemory); err != nil {
		writeError(w, http.StatusBadRequest,
			errors.New("file too large (max 100 MB) or malformed upload"))
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("no file provided"))
		return
	}
	defer file.Close()
	if header.Size > maxUploadBytes {
		writeError(w, http.StatusBadRequest,
			errors.New("file too large (max 100 MB)"))
		return
	}

	if err := os.MkdirAll(h.dir, 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	stored := randomHex(16) + filepath.Ext(header.Filename)
	dst := filepath.Join(h.dir, stored)
	out, err := os.Create(dst)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	written, copyErr := io.Copy(out, file)
	closeErr := out.Close()
	if copyErr != nil || closeErr != nil {
		_ = os.Remove(dst)
		writeError(w, http.StatusInternalServerError,
			errors.New("could not save file"))
		return
	}

	att, err := h.q.CreateAttachment(r.Context(), db.CreateAttachmentParams{
		TaskID:      id,
		UploaderID:  actorOf(r.Context()),
		Filename:    header.Filename,
		StoredName:  stored,
		ContentType: header.Header.Get("Content-Type"),
		Size:        written,
	})
	if err != nil {
		_ = os.Remove(dst)
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	logActivity(r.Context(), h.q, id, "attachment", header.Filename)
	writeJSON(w, http.StatusCreated, attachmentResponse{
		ID:          att.ID,
		TaskID:      att.TaskID,
		UploaderID:  att.UploaderID,
		Filename:    att.Filename,
		ContentType: att.ContentType,
		Size:        att.Size,
		CreatedAt:   att.CreatedAt,
	})
}

// DownloadAttachment streams a stored file. Mounted behind a middleware that
// accepts the token via query param (browser navigation can't set headers).
func (h *TaskHandler) DownloadAttachment(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	att, err := h.q.GetAttachment(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("attachment not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if att.ContentType != "" {
		w.Header().Set("Content-Type", att.ContentType)
	}
	w.Header().Set("Content-Disposition",
		fmt.Sprintf("attachment; filename=%q", att.Filename))
	http.ServeFile(w, r, filepath.Join(h.dir, att.StoredName))
}

// DeleteAttachment removes an attachment (uploader or admin) and its file.
func (h *TaskHandler) DeleteAttachment(w http.ResponseWriter, r *http.Request) {
	id, err := idParam(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid id"))
		return
	}
	att, err := h.q.GetAttachment(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, errors.New("attachment not found"))
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	c, _ := account.FromContext(r.Context())
	isUploader := att.UploaderID != nil && *att.UploaderID == c.UserID
	if !isUploader && !isAdmin(r.Context()) {
		writeError(w, http.StatusForbidden,
			errors.New("only the uploader or an admin can delete this file"))
		return
	}
	if err := h.q.DeleteAttachment(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	_ = os.Remove(filepath.Join(h.dir, att.StoredName))
	w.WriteHeader(http.StatusNoContent)
}

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
