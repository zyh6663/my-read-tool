package api

import (
	"net/http"
	"os"
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
			HasChapters: b.Format == "txt",
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

	// Build response with table of contents for TXT files
	type TOCItem struct {
		Index int    `json:"index"`
		Title string `json:"title"`
	}

	var toc []TOCItem

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
	}

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
		HasChapters: book.Format == "txt",
		TOC:         toc,
	}

	c.JSON(http.StatusOK, gin.H{
		"book": detail,
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

	if book.Format != "txt" {
		// For non-TXT books, return the whole file content
		content, err := os.ReadFile(book.FilePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to read book file",
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"chapter": models.Chapter{
				Index:   0,
				Title:   book.Title,
				Content: string(content),
			},
		})
		return
	}

	chapters, _, err := services.ParseTXTFile(book.FilePath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to parse book file",
		})
		return
	}

	index, err := strconv.Atoi(indexStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid chapter index",
		})
		return
	}

	// Convert to 0-based index
	if index < 0 || index >= len(chapters) {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Chapter not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"chapter": chapters[index],
	})
}
