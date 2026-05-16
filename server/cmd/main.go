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
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"*"},
		ExposeHeaders:    []string{"Content-Length", "Content-Type"},
		AllowCredentials: false,
		MaxAge:           12 * time.Hour,
	}))

	r.GET("/ping", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"message": "pong"}) })

	r.GET("/api/books", api.GetBooks)
	r.GET("/api/books/:id", api.GetBookByID)
	r.GET("/api/books/:id/chapters", api.GetChapters)
	r.GET("/api/books/:id/chapters/:index", api.GetChapterByIndex)
	r.GET("/api/books/:id/progress", api.GetProgress)
	r.PUT("/api/books/:id/progress", api.UpdateProgress)
	r.DELETE("/api/books/:id", api.DeleteBook)
	r.POST("/api/scan", api.TriggerScan)
	r.POST("/api/books/upload", api.UploadBook)

	searchHandler := api.NewSearchHandler()
	r.GET("/api/v1/search", searchHandler.Search)
	r.GET("/api/v1/search/detail", searchHandler.Detail)

	importHandler := api.NewImportHandler()
	r.POST("/api/v1/books/import", importHandler.Import)
	r.GET("/api/v1/books/import/progress", importHandler.Progress)

	bookShelfHandler := api.NewBookShelfHandler()
	bookshelf := r.Group("/api/bookshelf")
	bookshelf.Use(api.AuthMiddleware())
	{
		bookshelf.POST("/add", bookShelfHandler.AddToShelf)
		bookshelf.DELETE("/remove/:id", bookShelfHandler.RemoveFromShelf)
		bookshelf.GET("/list", bookShelfHandler.ListShelf)
		bookshelf.GET("/check/:book_id", bookShelfHandler.CheckInShelf)
	}

	authHandler := api.NewAuthHandler(database.DB)
	r.POST("/api/auth/register", authHandler.Register)
	r.POST("/api/auth/login", authHandler.Login)
	r.POST("/api/auth/migrate", authHandler.Migrate)

	sources := r.Group("/api/v1/sources")
	sources.Use(api.AuthMiddleware())
	{
		sources.GET("", api.ListSources)
		sources.POST("/import", api.ImportSource)
		sources.PUT("/:id", api.UpdateSource)
		sources.DELETE("/:id", api.DeleteSource)
		sources.POST("/:id/test", api.TestSource)
		sources.GET("/template", api.GetTemplate)
	}

	auth := r.Group("/api/auth")
	auth.Use(api.AuthMiddleware())
	{
		auth.GET("/me", authHandler.GetMe)
	}

	if err := r.Run("0.0.0.0:8080"); err != nil { panic(err) }
}
