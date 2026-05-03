package models

// Chapter represents a single chapter parsed from a TXT file.
type Chapter struct {
	Index   int    `json:"index"`
	Title   string `json:"title"`
	Content string `json:"content,omitempty"`
}

// ChapterInfo is a lightweight struct for the table of contents (no content).
type ChapterInfo struct {
	Index int    `json:"index"`
	Title string `json:"title"`
}
