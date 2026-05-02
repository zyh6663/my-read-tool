package models

import "gorm.io/gorm"

type Category struct {
	gorm.Model
	Name  string `json:"name" gorm:"size:128;not null"`
	Books []Book `json:"books" gorm:"foreignKey:CategoryID"`
}
