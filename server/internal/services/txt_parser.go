package services

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"purereader-server/internal/models"
)

// ChapterRegex matches common Chinese chapter headers that appear on a single line.
// Supported patterns:
//
//	"第x章 xxx"    — e.g. 第一章 科学边界, 第12章 三体问题
//	"第x回 xxx"    — e.g. 第一回 宴桃园豪杰三结义
//	"第x节 xxx"    — e.g. 第一节 引言
//	"第x部分 xxx"  — e.g. 第二部分 黑暗森林
//
// Also supports Chinese numeral digits: 一二三四五六七八九十百千万
var ChapterRegex = regexp.MustCompile(`^第[一二三四五六七八九十百千万0-9０-９]+[章回节部](.+)?$`)

// ============================================================================
// TxtParser — BookParser 接口实现
// ============================================================================

// TxtParser 是 TXT 格式的解析器，实现 BookParser 接口。
type TxtParser struct{}

// SupportedFormats 返回支持的扩展名列表。
func (p *TxtParser) SupportedFormats() []string {
	return []string{"txt"}
}

// Parse 实现 BookParser 接口，解析 TXT 文件。
func (p *TxtParser) Parse(filePath string) (*ParsedBook, error) {
	chapters, _, err := ParseTXTFile(filePath)
	if err != nil {
		return nil, err
	}

	title := strings.TrimSuffix(filepath.Base(filePath), filepath.Ext(filePath))

	parsedChapters := make([]ParsedChapter, len(chapters))
	for i, ch := range chapters {
		parsedChapters[i] = ParsedChapter{
			Index:   ch.Index,
			Title:   ch.Title,
			Content: ch.Content,
		}
	}

	return &ParsedBook{
		Title:    title,
		Author:   "",
		Chapters: parsedChapters,
		Metadata: map[string]string{"format": "txt"},
	}, nil
}

// init 自动注册 TxtParser 到全局解析器工厂。
func init() {
	RegisterParser(&TxtParser{})
}

// ============================================================================
// 以下为旧版兼容函数，保留给 handlers.go 中现有调用方使用。
// ============================================================================

// ParseTXTFile reads a TXT file and splits it into chapters.
// Returns the parsed chapters and a table-of-contents (without content).
// 该函数保持向后兼容，供 GetBookByID / GetChapters / GetChapterByIndex 等 Handler 使用。
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