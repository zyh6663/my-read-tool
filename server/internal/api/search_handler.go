package api

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"purereader-server/internal/services"
)

type SearchHandler struct{}

func NewSearchHandler() *SearchHandler { return &SearchHandler{} }

func (h *SearchHandler) Search(c *gin.Context) {
	keyword := c.Query("keyword")
	if keyword == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "keyword is required"})
		return
	}
	source := c.Query("source")
	page := 1
	if p := c.Query("page"); p != "" {
		if parsed, err := strconv.Atoi(p); err == nil && parsed > 0 {
			page = parsed
		}
	}
	results, err := services.SearchBooks(keyword, source, page)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": results})
}

func (h *SearchHandler) Detail(c *gin.Context) {
	sourceID, err := strconv.ParseUint(c.Query("source_id"), 10, 64)
	if err != nil || sourceID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "source_id is required"})
		return
	}
	bookID := c.Query("book_id")
	if bookID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "book_id is required"})
		return
	}
	detail, err := services.GetBookDetail(uint(sourceID), bookID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": detail})
}
