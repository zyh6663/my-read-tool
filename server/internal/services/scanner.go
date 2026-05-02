package services

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"purereader-server/internal/models"
	"purereader-server/pkg/database"

	"gorm.io/gorm"
)

// ScanLocalBooks walks through rootDir, identifies .epub / .txt files,
// uses the immediate parent folder name as the Category, and inserts
// new books into the database via GORM.
func ScanLocalBooks(rootDir string) int {
	newCount := 0

	err := filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			log.Printf("Error accessing path %s: %v", path, err)
			return nil // skip problematic entries
		}

		// We only care about regular files
		if info == nil {
			return nil
		}
		// Use type assertion to check if it's a regular file
		fi, ok := info.(interface {
			Name() string
			IsDir() bool
		})
		if !ok || fi.IsDir() {
			return nil
		}

		ext := strings.ToLower(filepath.Ext(fi.Name()))
		if ext != ".epub" && ext != ".txt" {
			return nil
		}

		// Derive category from the immediate parent directory name
		parentDir := filepath.Dir(path)
		categoryName := filepath.Base(parentDir)

		// --- Category lookup / creation ---
		var category models.Category
		result := database.DB.Where("name = ?", categoryName).First(&category)
		if result.Error != nil {
			if result.Error == gorm.ErrRecordNotFound {
				category = models.Category{Name: categoryName}
				if err := database.DB.Create(&category).Error; err != nil {
					log.Printf("Failed to create category %s: %v", categoryName, err)
					return nil
				}
				log.Printf("Created new category: %s", categoryName)
			} else {
				log.Printf("Error querying category %s: %v", categoryName, err)
				return nil
			}
		}

		// --- Book check / creation ---
		var existing models.Book
		if err := database.DB.Where("file_path = ?", path).First(&existing).Error; err == nil {
			// book already exists, skip
			return nil
		}

		title := strings.TrimSuffix(fi.Name(), filepath.Ext(fi.Name()))

		book := models.Book{
			Title:       title,
			FilePath:    path,
			Format:      ext[1:], // "epub" or "txt"
			StorageType: "local",
			IsPrivate:   false,
			CategoryID:  category.ID,
		}

		if err := database.DB.Create(&book).Error; err != nil {
			log.Printf("Failed to insert book %s: %v", title, err)
			return nil
		}

		newCount++
		log.Printf("Inserted new book: %s (category: %s)", title, categoryName)
		return nil
	})

	if err != nil {
		log.Printf("Error walking directory %s: %v", rootDir, err)
	}

	return newCount
}
