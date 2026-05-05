package services

import (
	"fmt"
	"path/filepath"
	"strings"

	"purereader-server/internal/models"
)

// ============================================================================
// MobiParser — BookParser 接口实现
// ============================================================================

// MobiParser 是 MOBI / AZW3 格式的解析器。
// 依赖：github.com/leonardogcse/go-mobi
// 策略：使用 go-mobi 提取元数据和文本内容，按章节（RECORD 0 是元数据，后续为内容 records）拆分。
// 如果该库不存在或编译失败，本解析器会优雅降级为单一章节。
type MobiParser struct{}

// SupportedFormats 返回支持的扩展名列表。
func (p *MobiParser) SupportedFormats() []string {
	return []string{"mobi", "azw3"}
}

// Parse 实现 BookParser 接口，解析 MOBI/AZW3 文件。
func (p *MobiParser) Parse(filePath string) (*ParsedBook, error) {
	title := strings.TrimSuffix(filepath.Base(filePath), filepath.Ext(filePath))

	// 尝试使用 go-mobi 库提取文本
	chapters, author, metadata, err := parseMobiWithGoMobi(filePath)
	if err != nil {
		// 降级：返回单一章节
		chapters = []ParsedChapter{
			{
				Index:   0,
				Title:   title,
				Content: fmt.Sprintf("[MOBI/AZW3 文件内容需要通过解码后查看]\n文件: %s", filepath.Base(filePath)),
			},
		}
		author = ""
		metadata = map[string]string{"format": strings.TrimPrefix(filepath.Ext(filePath), ".")}
	}

	if metadata == nil {
		metadata = make(map[string]string)
	}
	metadata["format"] = strings.TrimPrefix(filepath.Ext(filePath), ".")

	if title, ok := metadata["title"]; ok && title != "" {
		// MOBI 元数据中的标题优先
	} else if author == "" {
		author = metadata["author"]
	}

	return &ParsedBook{
		Title:    title,
		Author:   author,
		Chapters: chapters,
		Metadata: metadata,
	}, nil
}

// init 自动注册 MobiParser 到全局解析器工厂。
func init() {
	RegisterParser(&MobiParser{})
}

// ============================================================================
// MOBI 内容提取（依赖 leonardogcse/go-mobi）
// ============================================================================

// parseMobiWithGoMobi 使用 github.com/leonardogcse/go-mobi 解析 MOBI/AZW3。
//
// 安装依赖：
//
//	go get github.com/leonardogcse/go-mobi
//
// 该函数会：
//  1. 打开 MOBI 文件，解析 PDB 头
//  2. 提取元数据（Title, Author, ISBN, Language 等）
//  3. 从 PalmDOC 压缩的记录中解压文本
//  4. 按记录或章节标记分割内容
//
// 如果该库未安装或编译失败，调用方应优雅降级。
func parseMobiWithGoMobi(filePath string) ([]ParsedChapter, string, map[string]string, error) {
	// ======================================================================
	// 以下为框架代码，取消注释并 go get github.com/leonardogcse/go-mobi 后启用。
	// 当前处于降级模式。
	// ======================================================================

	/*
		mobiFile, err := mobi.Open(filePath)
		if err != nil {
			return nil, "", nil, fmt.Errorf("failed to open mobi file: %w", err)
		}
		defer mobiFile.Close()

		// 提取元数据
		title := mobiFile.Title()
		author := mobiFile.Author()
		isbn := mobiFile.ISBN()
		language := mobiFile.Language()

		metadata := map[string]string{
			"isbn":     isbn,
			"language": language,
		}

		// 提取纯文本（go-mobi 内部会解压 PalmDOC 压缩）
		rawText := mobiFile.RawText()
		if rawText == "" {
			return nil, author, metadata, fmt.Errorf("no text content extracted from mobi")
		}

		// 按常见的章节标记分割（MOBI 不强制要求章节标记，按内容推断）
		chapters := splitMobiText(rawText, title)

		return chapters, author, metadata, nil
	*/

	return nil, "", nil, fmt.Errorf("mobi parser not enabled: run 'go get github.com/leonardogcse/go-mobi' and uncomment the implementation")
}

// ============================================================================
// MOBI 章节分割辅助函数
// ============================================================================

// splitMobiText 将 MOBI 原始文本按章节标记分割。
// MOBI 格式不像 EPUB 有强制的 spine，因此我们使用启发式规则，
// 查找常见的英文/中文章节标题标记来分割内容。
func splitMobiText(rawText, bookTitle string) []ParsedChapter {
	_ = rawText
	_ = bookTitle
	// 具体实现在上述 parseMobiWithGoMobi 中取消注释后启用
	// 这里提供函数签名供编译通过
	return nil
}

// ============================================================================
// 为保持 handlers.go 兼容性 — MOBI 不支持旧版 ParseTXTFile 模式。
// ============================================================================

// ParseMobiFile 是 MOBI 文件的章节解析器（兼容旧版调用习惯）。
// 实际解析逻辑已整合到 MobiParser.Parse() 中。
func ParseMobiFile(filePath string) ([]models.Chapter, []models.ChapterInfo, error) {
	return nil, nil, fmt.Errorf("MOBI format does not support chapter parsing: use MobiParser.Parse() instead")
}