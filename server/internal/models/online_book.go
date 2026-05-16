package models

import "gorm.io/gorm"

// OnlineBook caches online search results and import metadata.
type OnlineBook struct {
	gorm.Model
	SourceID       uint   `json:"source_id" gorm:"index;not null"`
	SourceBookID   string `json:"source_book_id" gorm:"size:255;not null;uniqueIndex:idx_online_book_unique"`
	Title          string `json:"title" gorm:"size:255;not null"`
	Author         string `json:"author" gorm:"size:255"`
	Description    string `json:"description" gorm:"type:text"`
	CoverURL       string `json:"cover_url" gorm:"size:1024"`
	ChapterCount   int    `json:"chapter_count" gorm:"default:0"`
	CachedAt       int64  `json:"cached_at" gorm:"index"`
	Source         BookSource `json:"source" gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE;"`
}
