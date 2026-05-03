package main

import (
	"net/http"
	"time"

	"purereader-server/internal/api"
	"purereader-server/pkg/database"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	database.InitDB()

	r := gin.Default()

	// CORS 中间件 — 允许所有来源、所有方法、所有头部（开发环境最快方案）
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"*"},
		ExposeHeaders:    []string{"Content-Length", "Content-Type"},
		AllowCredentials: false,
		MaxAge:           12 * time.Hour,
	}))

	r.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "pong",
		})
	})

	r.GET("/api/books", api.GetBooks)
	r.GET("/api/books/:id", api.GetBookByID)
	r.GET("/api/books/:id/chapters/:index", api.GetChapterByIndex)
	r.POST("/api/scan", api.TriggerScan)

	if err := r.Run("0.0.0.0:8080"); err != nil {
		panic(err)
	}
}
