package api

import (
	"net/http"
	"strconv"

	"purereader-server/internal/models"
	"purereader-server/pkg/database"

	"github.com/gin-gonic/gin"
)

// BookShelfHandler 书架相关API处理器
type BookShelfHandler struct{}

// NewBookShelfHandler 创建 BookShelfHandler 实例
func NewBookShelfHandler() *BookShelfHandler {
	return &BookShelfHandler{}
}

// AddToShelf POST /api/bookshelf/add
// 添加书籍到书架
func (h *BookShelfHandler) AddToShelf(c *gin.Context) {
	userID := extractUserID(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Missing X-User-Id header",
		})
		return
	}

	var req struct {
		BookID uint `json:"book_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	if req.BookID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "book_id is required",
		})
		return
	}

	// 验证书籍是否存在
	var book models.Book
	if err := database.DB.First(&book, req.BookID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Book not found",
		})
		return
	}

	// 检查是否重复
	var existing models.BookShelf
	result := database.DB.Where("user_id = ? AND book_id = ?", userID, req.BookID).First(&existing)
	if result.Error == nil {
		c.JSON(http.StatusConflict, gin.H{
			"error":    "Book already in shelf",
			"shelf_id": existing.ID,
		})
		return
	}

	// 创建书架记录
	shelf := models.BookShelf{
		UserID: userID,
		BookID: req.BookID,
	}

	if err := database.DB.Create(&shelf).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to add book to shelf",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message":  "Book added to shelf",
		"shelf_id": shelf.ID,
		"book_id":  shelf.BookID,
	})
}

// RemoveFromShelf DELETE /api/bookshelf/remove/:id
// 从书架移除书籍
func (h *BookShelfHandler) RemoveFromShelf(c *gin.Context) {
	userID := extractUserID(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Missing X-User-Id header",
		})
		return
	}

	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid shelf ID",
		})
		return
	}

	var shelf models.BookShelf
	result := database.DB.First(&shelf, id)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Shelf record not found",
		})
		return
	}

	// 校验 user_id 归属
	if shelf.UserID != userID {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "You do not own this shelf record",
		})
		return
	}

	if err := database.DB.Delete(&shelf).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to remove from shelf",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Book removed from shelf",
	})
}

// ListShelf GET /api/bookshelf/list
// 获取书架列表
func (h *BookShelfHandler) ListShelf(c *gin.Context) {
	userID := extractUserID(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Missing X-User-Id header",
		})
		return
	}

	var shelves []models.BookShelf
	if err := database.DB.Preload("Book").Where("user_id = ?", userID).Order("added_at desc").Find(&shelves).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to query shelf",
		})
		return
	}

	// 构建响应，精简书籍信息（不含 content）
	type ShelfItem struct {
		ID      uint   `json:"id"`
		UserID  string `json:"user_id"`
		BookID  uint   `json:"book_id"`
		AddedAt string `json:"added_at"`
		Book    struct {
			ID     uint   `json:"id"`
			Title  string `json:"title"`
			Author string `json:"author"`
		} `json:"book"`
	}

	items := make([]ShelfItem, 0, len(shelves))
	for _, s := range shelves {
		item := ShelfItem{
			ID:      s.ID,
			UserID:  s.UserID,
			BookID:  s.BookID,
			AddedAt: s.AddedAt.Format("2006-01-02T15:04:05Z07:00"),
		}
		item.Book.ID = s.Book.ID
		item.Book.Title = s.Book.Title
		item.Book.Author = s.Book.Author
		items = append(items, item)
	}

	c.JSON(http.StatusOK, gin.H{
		"shelf": items,
	})
}

// CheckInShelf GET /api/bookshelf/check/:book_id
// 检查书籍是否在书架
func (h *BookShelfHandler) CheckInShelf(c *gin.Context) {
	userID := extractUserID(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Missing X-User-Id header",
		})
		return
	}

	bookIDStr := c.Param("book_id")
	bookID, err := strconv.ParseUint(bookIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid book_id",
		})
		return
	}

	var shelf models.BookShelf
	result := database.DB.Where("user_id = ? AND book_id = ?", userID, bookID).First(&shelf)

	if result.Error != nil {
		c.JSON(http.StatusOK, gin.H{
			"in_shelf": false,
			"shelf_id": 0,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"in_shelf": true,
		"shelf_id": shelf.ID,
	})
}