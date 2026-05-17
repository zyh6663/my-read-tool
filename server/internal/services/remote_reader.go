package services

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const remoteReaderTimeout = 15 * time.Second

// RemoteReader is an HTTP client for a remote book library.
type RemoteReader struct {
	BaseURL    string
	HTTPClient *http.Client
}

type RemoteBookInfo struct {
	Name string `json:"name"`
	Path string `json:"path"`
	Size int64  `json:"size"`
}

type RemoteChapterInfo struct {
	Index int    `json:"index"`
	Title string `json:"title"`
}

func NewRemoteReader(baseURL string) *RemoteReader {
	return &RemoteReader{
		BaseURL:    strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		HTTPClient: &http.Client{Timeout: remoteReaderTimeout},
	}
}

func (rr *RemoteReader) ListBooks() ([]RemoteBookInfo, error) {
	var payload struct {
		Books []RemoteBookInfo `json:"books"`
	}
	if err := rr.getJSON(rr.baseURL()+"/api/books", &payload); err != nil {
		return nil, err
	}
	return payload.Books, nil
}

func (rr *RemoteReader) GetChapters(bookPath string) ([]RemoteChapterInfo, error) {
	var payload struct {
		Chapters []RemoteChapterInfo `json:"chapters"`
	}
	endpoint := rr.baseURL() + "/api/books/chapters?path=" + url.QueryEscape(bookPath)
	if err := rr.getJSON(endpoint, &payload); err != nil {
		return nil, err
	}
	return payload.Chapters, nil
}

func (rr *RemoteReader) GetChapter(bookPath string, chapterIndex int) (string, error) {
	endpoint := rr.baseURL() + "/api/books/chapter?path=" + url.QueryEscape(bookPath) + "&idx=" + fmt.Sprint(chapterIndex)
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return "", err
	}

	resp, err := rr.httpClient().Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("GET %s failed: status=%s body=%s", endpoint, resp.Status, strings.TrimSpace(string(body)))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return string(body), nil
}

func (rr *RemoteReader) baseURL() string {
	if rr == nil {
		return ""
	}
	return strings.TrimRight(strings.TrimSpace(rr.BaseURL), "/")
}

func (rr *RemoteReader) httpClient() *http.Client {
	if rr != nil && rr.HTTPClient != nil {
		return rr.HTTPClient
	}
	return &http.Client{Timeout: remoteReaderTimeout}
}

func (rr *RemoteReader) getJSON(endpoint string, dst any) error {
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}

	resp, err := rr.httpClient().Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("GET %s failed: status=%s body=%s", endpoint, resp.Status, strings.TrimSpace(string(body)))
	}

	if err := json.NewDecoder(resp.Body).Decode(dst); err != nil {
		return err
	}
	return nil
}
