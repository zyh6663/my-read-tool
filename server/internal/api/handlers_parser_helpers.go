package api

import (
	"encoding/json"
	"fmt"
	"strconv"

	"purereader-server/internal/models"
	"purereader-server/internal/services"
)

// TOCItem 表示目录中的一个条目（索引 + 标题）。
// 与 handlers.go 中 GetBookByID 内定义的 TOCItem 类型一致。
type TOCItem struct {
	Index int    `json:"index"`
	Title string `json:"title"`
}

// buildTOC 从 Book 记录构建目录（TOC）。
//
// 对于 TXT 格式：调用 services.ParseTXTFile 实时解析。
// 对于其他格式：从 Book.Content (JSON) 中读取 ParsedChapter 列表并返回标题。
func buildTOC(book models.Book) []TOCItem {
	var toc []TOCItem

	if book.StorageType == "remote" {
		reader := services.NewRemoteReader(book.RemoteURL)
		remoteChapters, err := reader.GetChapters(book.FilePath)
		if err == nil {
			for _, rc := range remoteChapters {
				toc = append(toc, TOCItem{
					Index: rc.Index,
					Title: rc.Title,
				})
			}
		}
		return toc
	}

	if book.Format == "txt" {
		_, parsedTOC, err := services.ParseTXTFile(book.FilePath)
		if err == nil {
			for _, ci := range parsedTOC {
				toc = append(toc, TOCItem{
					Index: ci.Index,
					Title: ci.Title,
				})
			}
		}
		return toc
	}

	// 从数据库 JSON 字段读取
	chapters, err := loadParsedChapters(book)
	if err != nil {
		return toc
	}
	for _, ch := range chapters {
		toc = append(toc, TOCItem{
			Index: ch.Index,
			Title: ch.Title,
		})
	}
	return toc
}

// loadStoredTOC 从非 TXT 书籍的存储 JSON 中读取章节目录（不含内容）。
func loadStoredTOC(book models.Book) ([]models.ChapterInfo, error) {
	chapters, err := loadParsedChapters(book)
	if err != nil {
		return nil, err
	}
	toc := make([]models.ChapterInfo, len(chapters))
	for i, ch := range chapters {
		toc[i] = models.ChapterInfo{
			Index: ch.Index,
			Title: ch.Title,
		}
	}
	return toc, nil
}

// loadTXTChapter 从磁盘上的 TXT 文件中读取指定索引的章节。
func loadTXTChapter(book models.Book, indexStr string) (models.Chapter, error) {
	chapters, _, err := services.ParseTXTFile(book.FilePath)
	if err != nil {
		return models.Chapter{}, fmt.Errorf("failed to parse book file")
	}

	index, err := strconv.Atoi(indexStr)
	if err != nil {
		return models.Chapter{}, fmt.Errorf("invalid chapter index")
	}

	if index < 0 || index >= len(chapters) {
		return models.Chapter{}, fmt.Errorf("chapter not found")
	}

	return chapters[index], nil
}

// loadStoredChapter 从非 TXT 书籍的存储 JSON 中读取指定索引的章节（含内容）。
func loadStoredChapter(book models.Book, indexStr string) (models.Chapter, error) {
	chapters, err := loadParsedChapters(book)
	if err != nil {
		return models.Chapter{}, fmt.Errorf("failed to decode stored chapters")
	}

	index, err := strconv.Atoi(indexStr)
	if err != nil {
		return models.Chapter{}, fmt.Errorf("invalid chapter index")
	}

	if index < 0 || index >= len(chapters) {
		return models.Chapter{}, fmt.Errorf("chapter not found")
	}

	ch := chapters[index]
	return models.Chapter{
		Index:   ch.Index,
		Title:   ch.Title,
		Content: ch.Content,
	}, nil
}

// loadParsedChapters 从 Book.Content 字段（JSON）反序列化 ParsedChapter 列表。
func loadParsedChapters(book models.Book) ([]services.ParsedChapter, error) {
	if book.Content == "" {
		return nil, fmt.Errorf("no stored content")
	}
	var chapters []services.ParsedChapter
	if err := json.Unmarshal([]byte(book.Content), &chapters); err != nil {
		return nil, err
	}
	return chapters, nil
}