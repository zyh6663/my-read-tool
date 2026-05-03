package api

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"purereader-server/internal/models"
	"purereader-server/internal/services"
	"purereader-server/pkg/database"

	"github.com/gin-gonic/gin"
)

// UploadBook handles POST /api/books/upload.
// It receives a .txt file via multipart/form-data, saves it to
// books_storage/ with a timestamp-based name, parses the file
// into chapters using txt_parser, and writes the book record to
// the database. Returns the newly created book_id.
func UploadBook(c *gin.Context) {
	// 1. Receive the uploaded file
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No file provided. Use form field name 'file'.",
		})
		return
	}
	defer file.Close()

	// Validate extension
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if ext != ".txt" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Only .txt files are supported",
		})
		return
	}

	// 2. Save to books_storage/ with timestamp prefix
	storageDir := "./books_storage"
	if err := os.MkdirAll(storageDir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to ensure storage directory",
		})
		return
	}

	timestamp := time.Now().UnixMilli()
	saveName := fmt.Sprintf("%d_%s", timestamp, header.Filename)
	savePath := filepath.Join(storageDir, saveName)

	dst, err := os.Create(savePath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create file on server",
		})
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to save file",
		})
		return
	}

	// 3. Parse the TXT file (validate + extract chapters)
	chapters, _, err := services.ParseTXTFile(savePath)
	if err != nil {
		os.Remove(savePath)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to parse TXT file: " + err.Error(),
		})
		return
	}

	// Derive title from original filename (strip extension)
	title := strings.TrimSuffix(header.Filename, filepath.Ext(header.Filename))

	// 4. Write Book record to database
	book := models.Book{
		Title:       title,
		FilePath:    savePath,
		Format:      "txt",
		StorageType: "uploaded",
	}

	if err := database.DB.Create(&book).Error; err != nil {
		os.Remove(savePath)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to save book to database",
		})
		return
	}

	fmt.Printf("Uploaded and parsed book: %s (id=%d, chapters=%d)\n", title, book.ID, len(chapters))

	c.JSON(http.StatusOK, gin.H{
		"message":  "Book uploaded and parsed successfully",
		"book_id":  book.ID,
		"title":    title,
		"chapters": len(chapters),
	})
}
