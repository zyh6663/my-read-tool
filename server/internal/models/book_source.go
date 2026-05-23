package models

import "gorm.io/gorm"

type BookSource struct {
	gorm.Model
	Name      string `json:"name" gorm:"size:255;not null"`
	BaseURL   string `json:"base_url" gorm:"size:512;not null;uniqueIndex"`
	RuleJSON  string `json:"rule_json" gorm:"type:text;not null"`
	Enabled   bool   `json:"enabled" gorm:"default:true"`
	Priority  int    `json:"priority" gorm:"default:0"`
	IsBuiltin bool   `json:"is_builtin" gorm:"default:false"`
	UserID    string `json:"user_id" gorm:"index"`
}
