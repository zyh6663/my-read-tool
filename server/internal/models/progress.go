package models

import (
	"gorm.io/gorm"
)

type Progress struct {
	gorm.Model
	BookID       uint    `json:"book_id" gorm:"index;not null"`
	UserID       string  `json:"user_id" gorm:"index;default:''"`
	ChapterIndex int     `json:"chapter_index" gorm:"default:0"`
	Position     float64 `json:"position" gorm:"default:0"`
	TotalSeconds int64   `json:"total_seconds" gorm:"default:0"`
	LastReadAt   int64   `json:"last_read_at" gorm:"default:0"`
	Book         Book    `json:"book,omitempty" gorm:"foreignKey:BookID"`
}