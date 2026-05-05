package models

import "gorm.io/gorm"

type Book struct {
	gorm.Model
	Title       string   `json:"title" gorm:"size:255;not null"`
	Author      string   `json:"author" gorm:"size:255"`
	CoverURL    string   `json:"cover_url" gorm:"size:512"`
	FilePath    string   `json:"file_path" gorm:"size:512;not null"`
	Format      string   `json:"format" gorm:"size:32;not null"`
	StorageType string   `json:"storage_type" gorm:"size:32;not null;default:local"`
	IsPrivate   bool     `json:"is_private" gorm:"default:false"`
	CategoryID  uint     `json:"category_id"`
	Category    Category `json:"category" gorm:"foreignKey:CategoryID"`
	Tags        []*Tag   `json:"tags" gorm:"many2many:book_tags;"`
	Content     string   `json:"content" gorm:"type:longtext"`
	UserID      string   `json:"user_id" gorm:"size:64;index"` // 上传/拥有者用户ID
}
