package api

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"purereader-server/internal/models"
	"purereader-server/internal/services"
	"purereader-server/pkg/database"

	"github.com/gin-gonic/gin"
)

// TriggerScan is a Gin handler that calls ScanLocalBooks on the
// configured books storage directory and returns how many new
// books were imported.
func TriggerScan(c *gin.Context) {
	// Use a sensible default root directory; this can be extended
	// to read from config or request body in the future.
	rootDir := "./books_storage"

	newCount := services.ScanLocalBooks(rootDir)

	c.JSON(http.StatusOK, gin.H{
		"message":   "Scan completed",
		"new_books": newCount,
	})
}

// GetBooks returns all books (without file content or chapters).
func GetBooks(c *gin.Context) {
	var books []models.Book

	if err := database.DB.Preload("Category").Find(&books).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to query books",
		})
		return
	}

	// Strip content for list response
	type BookListItem struct {
		ID          uint   `json:"id"`
		Title       string `json:"title"`
		Author      string `json:"author"`
		CoverURL    string `json:"cover_url"`
		Format      string `json:"format"`
		StorageType string `json:"storage_type"`
		IsPrivate   bool   `json:"is_private"`
		CategoryID  uint   `json:"category_id"`
		Category    models.Category `json:"category"`
		HasChapters bool   `json:"has_chapters"`
	}

	items := make([]BookListItem, 0, len(books))
	for _, b := range books {
		items = append(items, BookListItem{
			ID:          b.ID,
			Title:       b.Title,
			Author:      b.Author,
			CoverURL:    b.CoverURL,
			Format:      b.Format,
			StorageType: b.StorageType,
			IsPrivate:   b.IsPrivate,
			CategoryID:  b.CategoryID,
			Category:    b.Category,
			HasChapters: b.Format == "txt" || len(b.Content) > 0,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"books": items,
	})
}

// GetBookByID returns a single book with its table of contents
// (chapter titles and indices only, no chapter content).
func GetBookByID(c *gin.Context) {
	id := c.Param("id")

	var book models.Book
	if err := database.DB.Preload("Category").Preload("Tags").First(&book, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Book not found",
		})
		return
	}

	// Build TOC from stored chapters or on-disk parsing
	toc := buildTOC(book)

	type BookDetail struct {
		ID          uint            `json:"id"`
		CreatedAt   string          `json:"created_at"`
		Title       string          `json:"title"`
		Author      string          `json:"author"`
		CoverURL    string          `json:"cover_url"`
		Format      string          `json:"format"`
		StorageType string          `json:"storage_type"`
		IsPrivate   bool            `json:"is_private"`
		CategoryID  uint            `json:"category_id"`
		Category    models.Category `json:"category"`
		Tags        []*models.Tag   `json:"tags"`
		HasChapters bool            `json:"has_chapters"`
		TOC         []TOCItem       `json:"toc"`
	}

	detail := BookDetail{
		ID:          book.ID,
		CreatedAt:   book.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		Title:       book.Title,
		Author:      book.Author,
		CoverURL:    book.CoverURL,
		Format:      book.Format,
		StorageType: book.StorageType,
		IsPrivate:   book.IsPrivate,
		CategoryID:  book.CategoryID,
		Category:    book.Category,
		Tags:        book.Tags,
		HasChapters: book.Format == "txt" || len(book.Content) > 0,
		TOC:         toc,
	}

	c.JSON(http.StatusOK, gin.H{
		"book": detail,
	})
}

// GetChapters returns a lightweight list of chapters (index + title only, no content).
// GET /api/books/:id/chapters
func GetChapters(c *gin.Context) {
	id := c.Param("id")

	var book models.Book
	if err := database.DB.First(&book, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Book not found",
		})
		return
	}

	var toc []models.ChapterInfo
	var err error

	if book.StorageType == "remote" {
		reader := services.NewRemoteReader(book.RemoteURL)
		remoteChapters, err := reader.GetChapters(book.FilePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load remote chapters: " + err.Error()})
			return
		}
		toc = make([]models.ChapterInfo, len(remoteChapters))
		for i, rc := range remoteChapters {
			toc[i] = models.ChapterInfo{
				Index: rc.Index,
				Title: rc.Title,
			}
		}
		c.JSON(http.StatusOK, gin.H{"chapters": toc})
		return
	}
	if book.StorageType == "online" {
		// FilePath format: "online://{sourceID}/{bookID}"
		sourceID, bookID, err := parseOnlinePath(book.FilePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid online file path: " + err.Error()})
			return
		}
		detail, err := services.GetBookDetail(sourceID, bookID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get online book detail: " + err.Error()})
			return
		}
		toc = make([]models.ChapterInfo, len(detail.Chapters))
		for i, ch := range detail.Chapters {
			toc[i] = models.ChapterInfo{
				Index: ch.Index,
				Title: ch.Title,
			}
		}
		c.JSON(http.StatusOK, gin.H{"chapters": toc})
		return
	}
	if book.Format == "txt" {
		_, toc, err = services.ParseTXTFile(book.FilePath)
	} else {
		toc, err = loadStoredTOC(book)
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to parse book chapters",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"chapters": toc,
	})
}

// GetChapterByIndex returns the content of a specific chapter.
func GetChapterByIndex(c *gin.Context) {
	id := c.Param("id")
	indexStr := c.Param("index")

	var book models.Book
	if err := database.DB.First(&book, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Book not found",
		})
		return
	}

	var chapter models.Chapter
	var err error

	if book.StorageType == "remote" {
		reader := services.NewRemoteReader(book.RemoteURL)
		index, err := strconv.Atoi(indexStr)
		if err != nil {
			c.JSON(400, gin.H{"error": "invalid chapter index"})
			return
		}
		content, err := reader.GetChapter(book.FilePath, index)
		if err != nil {
			c.JSON(500, gin.H{"error": "Failed to load remote chapter: " + err.Error()})
			return
		}
		c.JSON(200, gin.H{"chapter": models.Chapter{
			Index:   index,
			Title:   fmt.Sprintf("第%d章", index),
			Content: content,
		}})
		return
	}
	if book.StorageType == "online" {
		sourceID, bookID, err := parseOnlinePath(book.FilePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid online file path: " + err.Error()})
			return
		}
		index, err := strconv.Atoi(indexStr)
		if err != nil {
			c.JSON(400, gin.H{"error": "invalid chapter index"})
			return
		}
		// Load from cached content first, then fall back to fetching from source
		if book.Content != "" {
			contentStr, title, err := services.ExtractChapterFromContent(book.Content, index)
			if err == nil {
				c.JSON(200, gin.H{"chapter": models.Chapter{
					Index:   index,
					Title:   title,
					Content: contentStr,
				}})
				return
			}
		}
		// Fallback: fetch from source engine
		detail, err := services.GetBookDetail(sourceID, bookID)
		if err != nil {
			c.JSON(500, gin.H{"error": "Failed to get online book detail: " + err.Error()})
			return
		}
		if index < 0 || index >= len(detail.Chapters) {
			c.JSON(400, gin.H{"error": "chapter index out of range"})
			return
		}
		ch := detail.Chapters[index]
		content, err := services.GetChapterContent(sourceID, bookID, ch.URL)
		if err != nil {
			c.JSON(500, gin.H{"error": "Failed to get chapter content: " + err.Error()})
			return
		}
		c.JSON(200, gin.H{"chapter": models.Chapter{
			Index:   ch.Index,
			Title:   ch.Title,
			Content: content,
		}})
		return
	}

	if book.Format == "txt" {
		chapter, err = loadTXTChapter(book, indexStr)
	} else {
		chapter, err = loadStoredChapter(book, indexStr)
	}

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"chapter": chapter,
	})
}

// RemoteListBooks returns the full list of books from all enabled remote book sources.
// GET /api/books/remote_list
func RemoteListBooks(c *gin.Context) {
	sources, err := services.LoadEnabledSources()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load sources: " + err.Error()})
		return
	}

	type RemoteBookItem struct {
		SourceID     uint   `json:"source_id"`
		SourceName   string `json:"source_name"`
		SourceBookID string `json:"source_book_id"`
		Title        string `json:"title"`
		Author       string `json:"author"`
	}

	var allBooks []RemoteBookItem
	for _, src := range sources {
		if src.Rule.ResponseType == "json" {
			// For JSON sources (e.g. biquge), fetch and parse the complete book list
			listURL := strings.ReplaceAll(src.Rule.Search.URL, "{keyword}", "")
			listURL = strings.TrimRight(listURL, "?q=")
			// The biquge source has URL "/api/books/search?q={keyword}"
			// We need a dedicated list endpoint. Reuse the search with a broad query.
			reader := services.NewRemoteReader(src.BaseURL)
			remoteBooks, err := reader.ListBooks()
			if err != nil {
				continue
			}
			for _, rb := range remoteBooks {
				allBooks = append(allBooks, RemoteBookItem{
					SourceID:     src.ID,
					SourceName:   src.Name,
					SourceBookID: rb.Path,
					Title:        rb.Name,
					Author:       "",
				})
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{"data": allBooks})
}

// extractUserID resolves the current user from either the JWT auth middleware
// or the legacy X-User-Id header used by older clients.
func extractUserID(c *gin.Context) string {
	if userID, exists := c.Get("user_id"); exists {
		switch v := userID.(type) {
		case string:
			return v
		case uint:
			return strconv.FormatUint(uint64(v), 10)
		case uint64:
			return strconv.FormatUint(v, 10)
		case int:
			return strconv.Itoa(v)
		case int64:
			return strconv.FormatInt(v, 10)
		}
	}
	return c.GetHeader("X-User-Id")
}

// GetProgress returns the reading progress for a given book (scoped to user).
func GetProgress(c *gin.Context) {
	id := c.Param("id")
	userID := extractUserID(c)

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Missing X-User-Id header",
		})
		return
	}

	var book models.Book
	if err := database.DB.First(&book, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Book not found",
		})
		return
	}

	var progress models.Progress
	result := database.DB.Where("book_id = ? AND user_id = ?", book.ID, userID).First(&progress)
	if result.Error != nil {
		// No progress record yet – return default (chapter 0)
		c.JSON(http.StatusOK, gin.H{
			"book_id":       book.ID,
			"user_id":       userID,
			"chapter_index": 0,
			"position":      0,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"book_id":       progress.BookID,
		"user_id":       progress.UserID,
		"chapter_index": progress.ChapterIndex,
		"position":      progress.Position,
	})
}

// DeleteBook deletes a book and its associated progress records.
func DeleteBook(c *gin.Context) {
	id := c.Param("id")

	var book models.Book
	if err := database.DB.First(&book, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Book not found",
		})
		return
	}

	// Delete progress records associated with this book
	if err := database.DB.Where("book_id = ?", book.ID).Delete(&models.Progress{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete progress records",
		})
		return
	}

	// Delete the book record
	if err := database.DB.Delete(&book).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete book",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Book deleted successfully",
	})
}

// UpdateProgress saves or updates the reading progress for a given book (scoped to user).
func UpdateProgress(c *gin.Context) {
	id := c.Param("id")
	userID := extractUserID(c)

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Missing X-User-Id header",
		})
		return
	}

	var book models.Book
	if err := database.DB.First(&book, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Book not found",
		})
		return
	}

	var req struct {
		ChapterIndex int     `json:"chapter_index"`
		Position     float64 `json:"position"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	var progress models.Progress
	result := database.DB.Where("book_id = ? AND user_id = ?", book.ID, userID).First(&progress)
	if result.Error != nil {
		// Create new progress record
		progress = models.Progress{
			BookID:       book.ID,
			UserID:       userID,
			ChapterIndex: req.ChapterIndex,
			Position:     req.Position,
		}
		if err := database.DB.Create(&progress).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to save progress",
			})
			return
		}
	} else {
		// Update existing record
		progress.ChapterIndex = req.ChapterIndex
		progress.Position = req.Position
		if err := database.DB.Save(&progress).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to update progress",
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"book_id":       progress.BookID,
		"user_id":       progress.UserID,
		"chapter_index": progress.ChapterIndex,
		"position":      progress.Position,
	})
}
