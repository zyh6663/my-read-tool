package database

import (
	"log"

	"purereader-server/internal/models"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func InitDB() {
	var err error
	DB, err = gorm.Open(sqlite.Open("purereader.db"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatalf("failed to connect database: %v", err)
	}

	err = DB.AutoMigrate(
		&models.Book{},
		&models.Category{},
		&models.Tag{},
		&models.Progress{},
		&models.BookShelf{},
		&models.User{},
	)
	if err != nil {
		log.Fatalf("failed to auto migrate: %v", err)
	}

	log.Println("Database initialized and migrated successfully")
}