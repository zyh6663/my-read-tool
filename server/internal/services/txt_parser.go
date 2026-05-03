package services

import (
	"os"
	"regexp"
	"strings"

	"purereader-server/internal/models"
)

// ChapterRegex matches common Chinese chapter headers that appear on a single line.
// Supported patterns:
//   "第x章 xxx"    — e.g. 第一章 科学边界, 第12章 三体问题
//   "第x回 xxx"    — e.g. 第一回 宴桃园豪杰三结义
//   "第x节 xxx"    — e.g. 第一节 引言
//   "第x部分 xxx"  — e.g. 第二部分 黑暗森林
// Also supports Chinese numeral digits: 一二三四五六七八九十百千万
var ChapterRegex = regexp.MustCompile(`^第[一二三四五六七八九十百千万0-9０-９]+[章回节部](.+)?$`)

// ParseTXTFile reads a TXT file and splits it into chapters.
// Returns the parsed chapters and a table-of-contents (without content).
func ParseTXTFile(filePath string) ([]models.Chapter, []models.ChapterInfo, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, nil, err
	}

	text := string(data)
	// Normalize line endings
	text = strings.ReplaceAll(text, "\r\n", "\n")
	text = strings.ReplaceAll(text, "\r", "\n")

	lines := strings.Split(text, "\n")

	var chapters []models.Chapter
	currentChapter := models.Chapter{
		Index: 0,
		Title: "前言",
	}

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}

		matches := ChapterRegex.FindStringSubmatch(trimmed)
		if matches != nil {
			// Save previous chapter if it has content
			if currentChapter.Content != "" {
				chapters = append(chapters, currentChapter)
			}

			// Start new chapter
			title := trimmed
			currentChapter = models.Chapter{
				Index: len(chapters) + 1,
				Title: title,
			}
		} else {
			if currentChapter.Content != "" {
				currentChapter.Content += "\n" + trimmed
			} else {
				currentChapter.Content = trimmed
			}
		}
	}

	// Append the last chapter
	if currentChapter.Content != "" || len(chapters) == 0 {
		chapters = append(chapters, currentChapter)
	}

	// Build TOC (without content)
	toc := make([]models.ChapterInfo, len(chapters))
	for i, ch := range chapters {
		toc[i] = models.ChapterInfo{
			Index: ch.Index,
			Title: ch.Title,
		}
	}

	return chapters, toc, nil
}

