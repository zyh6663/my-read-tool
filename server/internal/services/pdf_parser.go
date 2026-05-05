package services

import (
	"fmt"
	"path/filepath"
	"strings"

	"purereader-server/internal/models"
)

// ============================================================================
// PdfParser — BookParser 接口实现（简化版）
// ============================================================================

// PdfParser 是 PDF 格式的解析器。
// 依赖：github.com/ledongthuc/pdf
// 策略：将 PDF 按页拆分，每一页作为一个章节，书名从文件名回退推断。
// 如果 `go get` 的库不存在或编译失败，本解析器会优雅降级为空章节列表。
type PdfParser struct{}

// SupportedFormats 返回支持的扩展名列表。
func (p *PdfParser) SupportedFormats() []string {
	return []string{"pdf"}
}

// Parse 实现 BookParser 接口，解析 PDF 文件。
// 当前为简化版实现：返回空章节列表，书名从文件名推断。
// 完整实现需要 github.com/ledongthuc/pdf，参见下方的 ParsePDF 注释。
func (p *PdfParser) Parse(filePath string) (*ParsedBook, error) {
	title := strings.TrimSuffix(filepath.Base(filePath), filepath.Ext(filePath))

	// 尝试使用 ledongthuc/pdf 库提取文本
	chapters, author, err := parsePdfWithLedongthuc(filePath, title)
	if err != nil {
		// 降级：返回空章节列表，不中断流程
		chapters = []ParsedChapter{
			{
				Index:   0,
				Title:   title,
				Content: fmt.Sprintf("[PDF 文件内容需要通过专用阅读器查看]\n文件: %s", filepath.Base(filePath)),
			},
		}
		author = ""
	}

	return &ParsedBook{
		Title:    title,
		Author:   author,
		Chapters: chapters,
		Metadata: map[string]string{"format": "pdf"},
	}, nil
}

// init 自动注册 PdfParser 到全局解析器工厂。
func init() {
	RegisterParser(&PdfParser{})
}

// ============================================================================
// PDF 内容提取（依赖 ledongthuc/pdf）
// ============================================================================

// parsePdfWithLedongthuc 使用 github.com/ledongthuc/pdf 解析 PDF 文本。
//
// 安装依赖：
//
//	go get github.com/ledongthuc/pdf
//
// 该函数会：
//  1. 打开 PDF 文件
//  2. 逐页读取文本
//  3. 每一页作为一个章节返回
//
// 如果该库未安装或编译失败，调用方应优雅降级。
func parsePdfWithLedongthuc(filePath string, fallbackTitle string) ([]ParsedChapter, string, error) {
	// ======================================================================
	// 以下为框架代码，取消注释并 go get github.com/ledongthuc/pdf 后即可启用。
	// 当前处于降级模式：返回一个包含提示信息的默认章节。
	// ======================================================================

	/*
		f, r, err := pdf.Open(filePath)
		if err != nil {
			return nil, "", fmt.Errorf("failed to open PDF: %w", err)
		}
		defer f.Close()

		totalPage := r.NumPage()

		var chapters []ParsedChapter
		author := ""

		for pageNum := 1; pageNum <= totalPage; pageNum++ {
			page := r.Page(pageNum)
			if page.V.IsNull() {
				continue
			}

			text, err := page.GetPlainText(nil)
			if err != nil {
				continue
			}

			text = strings.TrimSpace(text)
			if text == "" {
				continue
			}

			chapters = append(chapters, ParsedChapter{
				Index:   len(chapters),
				Title:   fmt.Sprintf("第 %d 页", pageNum),
				Content: text,
			})
		}

		if len(chapters) == 0 {
			chapters = []ParsedChapter{
				{
					Index:   0,
					Title:   fallbackTitle,
					Content: "[PDF 文件未能提取到文本内容]",
				},
			}
		}

		return chapters, author, nil
	*/

	return nil, "", fmt.Errorf("pdf parser not enabled: run 'go get github.com/ledongthuc/pdf' and uncomment the implementation")
}

// ============================================================================
// 为保持 handlers.go 兼容性 — PDF 版 ParseTXTFile 不存在，保留空函数声明。
// PDF 不支持章节解析，handlers.go 中通过格式判断分流。
// ============================================================================

// ParsePDFFile 是 PDF 文件的章节解析器（兼容旧版调用习惯）。
// 实际解析逻辑已整合到 PdfParser.Parse() 中。
func ParsePDFFile(filePath string) ([]models.Chapter, []models.ChapterInfo, error) {
	return nil, nil, fmt.Errorf("PDF format does not support chapter parsing: use PdfParser.Parse() instead")
}