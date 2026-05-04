package models

import "time"

// BookShelf 书架收藏记录
type BookShelf struct {
	ID      uint      `gorm:"primaryKey" json:"id"`
	UserID  string    `gorm:"index;not null" json:"user_id"` // 对应 X-User-Id
	BookID  uint      `gorm:"index;not null" json:"book_id"` // 关联 books 表主键
	AddedAt time.Time `gorm:"autoCreateTime" json:"added_at"`
	// GORM 外键关联
	Book Book `gorm:"foreignKey:BookID" json:"book,omitempty"`
}