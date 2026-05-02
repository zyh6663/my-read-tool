package models

import "gorm.io/gorm"

type Tag struct {
	gorm.Model
	Name  string  `json:"name" gorm:"size:128;not null;uniqueIndex"`
	Books []*Book `json:"books" gorm:"many2many:book_tags;"`
}
