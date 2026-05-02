package api

import (
	"net/http"
	"os"

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

// GetBooks returns all books with their associated category details.
func GetBooks(c *gin.Context) {
	var books []models.Book

	if err := database.DB.Preload("Category").Find(&books).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to query books",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"books": books,
	})
}

// GetBookByID returns a single book with full content by its ID.
func GetBookByID(c *gin.Context) {
	id := c.Param("id")

	var book models.Book
	if err := database.DB.Preload("Category").Preload("Tags").First(&book, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Book not found",
		})
		return
	}

	// Read file content from disk
	content, err := os.ReadFile(book.FilePath)
	if err == nil {
		book.Content = string(content)
	} else {
		// If file cannot be read, return empty content (non-fatal)
		book.Content = ""
	}

	c.JSON(http.StatusOK, gin.H{
		"book": book,
	})
}
