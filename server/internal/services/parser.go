package services

import (
	"fmt"
)

// ParsedBook 解析后的书籍结构体，由各格式解析器返回。
// 注意：import 路径使用 go.mod 中定义的模块名 purereader-server，
// 如果你的 go.mod 模块名不同，请全局替换。
type ParsedBook struct {
	Title    string            // 书名
	Author   string            // 作者
	Chapters []ParsedChapter   // 章节列表（有序）
	Metadata map[string]string // 格式相关元数据（如 ISBN、出版社、封面路径等）
}

// ParsedChapter 解析后的章节结构体。
type ParsedChapter struct {
	Index   int    // 章节序号（从 0 开始）
	Title   string // 章节标题
	Content string // 章节正文（纯文本）
}

// BookParser 书籍解析器接口。
// 每种电子书格式（txt, epub, pdf, mobi, azw3）都需要实现此接口。
type BookParser interface {
	// Parse 从文件路径解析电子书，返回 ParsedBook 或错误。
	// 调用方应在解析完成后自行清理临时文件。
	Parse(filePath string) (*ParsedBook, error)

	// SupportedFormats 返回该解析器支持的文件扩展名列表（小写，不含点号）。
	// 例如：[]string{"txt"}、[]string{"epub"}、[]string{"mobi", "azw3"}
	SupportedFormats() []string
}

// FormatNotSupportedError 表示请求的格式没有对应的解析器。
type FormatNotSupportedError struct {
	Format string
}

func (e *FormatNotSupportedError) Error() string {
	return fmt.Sprintf("unsupported format: %s", e.Format)
}