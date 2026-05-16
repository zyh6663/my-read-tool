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
	r.GET("/api/books/:id/chapters", api.GetChapters)
	r.GET("/api/books/:id/chapters/:index", api.GetChapterByIndex)
	r.GET("/api/books/:id/progress", api.GetProgress)
	r.PUT("/api/books/:id/progress", api.UpdateProgress)
	r.DELETE("/api/books/:id", api.DeleteBook)
	r.POST("/api/scan", api.TriggerScan)
	r.POST("/api/books/upload", api.UploadBook)

	// 书架相关路由
	bookShelfHandler := api.NewBookShelfHandler()
	bookshelf := r.Group("/api/bookshelf")
	bookshelf.Use(api.AuthMiddleware())
	{
		bookshelf.POST("/add", bookShelfHandler.AddToShelf)
		bookshelf.DELETE("/remove/:id", bookShelfHandler.RemoveFromShelf)
		bookshelf.GET("/list", bookShelfHandler.ListShelf)
		bookshelf.GET("/check/:book_id", bookShelfHandler.CheckInShelf)
	}

	// 认证相关路由
	authHandler := api.NewAuthHandler(database.DB)
	r.POST("/api/auth/register", authHandler.Register)
	r.POST("/api/auth/login", authHandler.Login)
	r.POST("/api/auth/migrate", authHandler.Migrate)

	auth := r.Group("/api/auth")
	auth.Use(api.AuthMiddleware())
	{
		auth.GET("/me", authHandler.GetMe)
	}

	if err := r.Run("0.0.0.0:8080"); err != nil {
		panic(err)
	}
}