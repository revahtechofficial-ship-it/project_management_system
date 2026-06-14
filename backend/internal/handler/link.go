package handler

import (
	"errors"
	"html"
	"io"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

type linkPreview struct {
	URL         string `json:"url"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Image       string `json:"image"`
	Site        string `json:"site"`
}

var (
	ogClient = &http.Client{Timeout: 6 * time.Second}
	metaRe   = regexp.MustCompile(`(?is)<meta\s+[^>]*>`)
	attrRe   = regexp.MustCompile(`(?is)([\w:-]+)\s*=\s*["']([^"']*)["']`)
	titleRe  = regexp.MustCompile(`(?is)<title[^>]*>(.*?)</title>`)
)

// LinkPreview fetches a URL server-side (avoiding browser CORS) and returns its
// Open Graph metadata for rendering a rich preview card in chat.
func LinkPreview(w http.ResponseWriter, r *http.Request) {
	raw := strings.TrimSpace(r.URL.Query().Get("url"))
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		writeError(w, http.StatusBadRequest, errors.New("invalid url"))
		return
	}
	if isPrivateHost(u.Hostname()) {
		writeError(w, http.StatusForbidden, errors.New("host not allowed"))
		return
	}

	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, raw, nil)
	if err != nil {
		writeJSON(w, http.StatusOK, linkPreview{URL: raw, Site: u.Hostname()})
		return
	}
	req.Header.Set("User-Agent",
		"Mozilla/5.0 (compatible; RevahBot/1.0; +link-preview)")
	resp, err := ogClient.Do(req)
	if err != nil {
		writeJSON(w, http.StatusOK, linkPreview{URL: raw, Site: u.Hostname()})
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 512*1024))
	doc := string(body)

	pv := linkPreview{
		URL:         raw,
		Title:       metaContent(doc, "og:title"),
		Description: metaContent(doc, "og:description"),
		Image:       metaContent(doc, "og:image"),
		Site:        metaContent(doc, "og:site_name"),
	}
	if pv.Title == "" {
		pv.Title = titleTag(doc)
	}
	if pv.Description == "" {
		pv.Description = metaContent(doc, "description")
	}
	if pv.Site == "" {
		pv.Site = u.Hostname()
	}
	writeJSON(w, http.StatusOK, pv)
}

// metaContent returns the content of the first <meta> tag whose property or
// name attribute equals key.
func metaContent(doc, key string) string {
	for _, tag := range metaRe.FindAllString(doc, -1) {
		attrs := make(map[string]string)
		for _, m := range attrRe.FindAllStringSubmatch(tag, -1) {
			attrs[strings.ToLower(m[1])] = m[2]
		}
		if attrs["property"] == key || attrs["name"] == key {
			return strings.TrimSpace(html.UnescapeString(attrs["content"]))
		}
	}
	return ""
}

func titleTag(doc string) string {
	if m := titleRe.FindStringSubmatch(doc); len(m) == 2 {
		return strings.TrimSpace(html.UnescapeString(m[1]))
	}
	return ""
}

// isPrivateHost guards against SSRF by blocking loopback / private / link-local
// targets.
func isPrivateHost(host string) bool {
	if host == "localhost" {
		return true
	}
	if ip := net.ParseIP(host); ip != nil {
		return ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast()
	}
	ips, err := net.LookupIP(host)
	if err != nil {
		return false
	}
	for _, ip := range ips {
		if ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() {
			return true
		}
	}
	return false
}
