package api

import (
	"net/http"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"purereader-server/internal/models"
	"purereader-server/internal/services"
	"purereader-server/pkg/database"
)

type RemoteImportHandler struct {
	readerFactory func(string) *services.RemoteReader
	categorizer   *services.Categorizer
}

func NewRemoteImportHandler() *RemoteImportHandler {
	return &RemoteImportHandler{
		readerFactory: services.NewRemoteReader,
		categorizer:   services.NewCategorizer(),
	}
}

func RemoteImport(c *gin.Context) {
	NewRemoteImportHandler().RemoteImport(c)
}

func (h *RemoteImportHandler) RemoteImport(c *gin.Context) {
	var req struct {
		ServerURL string `json:"server_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.ServerURL) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "server_url is required"})
		return
	}

	reader := h.readerFactory(req.ServerURL)
	books, err := reader.ListBooks()
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "failed to fetch remote books", "detail": err.Error()})
		return
	}

	imported := 0
	skipped := 0
	failed := 0

	for _, remoteBook := range books {
		title := strings.TrimSuffix(filepath.Base(remoteBook.Name), filepath.Ext(remoteBook.Name))
		if title == "" {
			title = strings.TrimSuffix(filepath.Base(remoteBook.Path), filepath.Ext(remoteBook.Path))
		}
		if title == "" {
			failed++
			continue
		}

		if err := database.DB.Transaction(func(tx *gorm.DB) error {
			var existing models.Book
			if err := tx.Where("title = ? AND file_path = ? AND remote_url = ?", title, remoteBook.Path, req.ServerURL).First(&existing).Error; err == nil {
				skipped++
				return nil
			} else if err != nil && err != gorm.ErrRecordNotFound {
				return err
			}

			categoryName := h.categorizer.Categorize(title)
			var category models.Category
			if err := tx.Where("name = ?", categoryName).First(&category).Error; err != nil {
				if err != gorm.ErrRecordNotFound {
					return err
				}
				category = models.Category{Name: categoryName}
				if err := tx.Create(&category).Error; err != nil {
					return err
				}
			}

			book := models.Book{
				Title:       title,
				Author:      "",
				FilePath:    remoteBook.Path,
				Format:      "txt",
				StorageType: "remote",
				RemoteURL:   strings.TrimRight(strings.TrimSpace(req.ServerURL), "/"),
				CategoryID:  category.ID,
				IsPrivate:   false,
			}
			if err := tx.Create(&book).Error; err != nil {
				return err
			}

			imported++
			return nil
		}); err != nil {
			failed++
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"imported": imported,
		"total":    len(books),
		"message":  "remote import completed",
		"skipped":  skipped,
		"failed":   failed,
	})
}
