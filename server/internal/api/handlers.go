package api

import (
	"net/http"
	"strconv"

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
