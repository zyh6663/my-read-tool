package api

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"purereader-server/internal/models"
	"purereader-server/internal/services"
	"purereader-server/pkg/database"

	"github.com/gin-gonic/gin"
)

// UploadBook handles POST /api/books/upload.
//
// 重构后的上传流程（策略模式 + 工厂）：
//  1. 接收前端的 Multipart Form 上传文件。
//  2. 提取文件扩展名（转小写），调用 services.GetParser(ext) 获取对应解析器。
//  3. 如果返回 error（不支持的格式），立即向前端返回 HTTP 400 和友好的错误提示。
//  4. 将文件临时保存到磁盘，调用 parser.Parse(tmpFilePath)。
//  5. 解析成功后：
//     - 从请求上下文中提取 userID（AuthMiddleware 注入或 X-User-Id 头）。
//     - 利用 GORM 将 ParsedBook 的信息和 ParsedChapter 列表关联该 userID 存入 SQLite。
//     - 删除临时文件（defer 确保即使 panic 也会清理）。
//  6. 返回标准的 JSON 响应（包含生成的 book_id）。
func UploadBook(c *gin.Context) {
	// 1. 接收上传文件
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "未提供文件。请使用表单字段名 'file' 上传文件。",
		})
		return
	}
	defer file.Close()

	// 2. 提取扩展名（小写），获取对应解析器
	ext := strings.TrimPrefix(strings.ToLower(filepath.Ext(header.Filename)), ".")

	parser, err := services.GetParser(ext)
	if err != nil {
		// 不支持的格式 — 返回友好错误，列出支持的格式
		supported := strings.Join(services.SupportedFormats(), ", ")
		c.JSON(http.StatusBadRequest, gin.H{
			"error":             fmt.Sprintf("不支持的文件格式 .%s", ext),
			"supported_formats": supported,
		})
		return
	}

	// 3. 保存临时文件
	storageDir := "./books_storage"
	if err := os.MkdirAll(storageDir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "无法创建存储目录",
		})
		return
	}

	timestamp := time.Now().UnixMilli()
	tmpName := fmt.Sprintf("%d_%s", timestamp, header.Filename)
	tmpPath := filepath.Join(storageDir, tmpName)

	dst, err := os.Create(tmpPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "无法创建临时文件",
		})
		return
	}

	if _, err := io.Copy(dst, file); err != nil {
		dst.Close()
		os.Remove(tmpPath)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "文件保存失败",
		})
		return
	}
	dst.Close()

	// 确保无论如何都清理临时文件（仅解析成功后删除；失败也删除）
	defer func() {
		if _, statErr := os.Stat(tmpPath); statErr == nil {
			os.Remove(tmpPath)
		}
	}()

	// 4. 调用解析器解析文件（recover 防止单个解析器 panic 导致服务崩溃）
	var parsed *services.ParsedBook

	func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Parser panic for format %q: %v", ext, r)
				parsed = nil
			}
		}()

		parsed, err = parser.Parse(tmpPath)
	}()

	if err != nil || parsed == nil {
		if err == nil {
			err = fmt.Errorf("解析器内部错误")
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("文件解析失败: %v", err),
		})
		return
	}

	// 5. 提取用户 ID
	// 优先从 AuthMiddleware 注入的上下文中读取，其次从 X-User-Id 头读取
	userID := extractUserIDFromContext(c)

	// 6. 将章节序列化为 JSON 存入 Book.Content
	chaptersJSON, err := json.Marshal(parsed.Chapters)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "章节数据序列化失败",
		})
		return
	}

	// 将原临时文件持久化到正式路径（上传完成）
	finalPath := filepath.Join(storageDir, tmpName)

	// 构建 Book 记录
	book := models.Book{
		Title:       parsed.Title,
		Author:      parsed.Author,
		FilePath:    finalPath,
		Format:      ext,
		StorageType: "uploaded",
		Content:     string(chaptersJSON),
		UserID:      userID,
	}

	if err := database.DB.Create(&book).Error; err != nil {
		os.Remove(tmpPath)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "书籍数据保存失败",
		})
		return
	}

	log.Printf("[Upload] Book saved: id=%d, title=%q, format=%s, chapters=%d, user=%s",
		book.ID, book.Title, ext, len(parsed.Chapters), userID)

	// 7. 返回成功响应
	c.JSON(http.StatusOK, gin.H{
		"message":  "文件上传并解析成功",
		"book_id":  book.ID,
		"title":    book.Title,
		"author":   book.Author,
		"format":   ext,
		"chapters": len(parsed.Chapters),
	})
}

// extractUserIDFromContext 从请求上下文中提取用户 ID。
// 优先从 AuthMiddleware 设置的 context value 中读取，
// 其次从 X-User-Id 请求头中读取（兼容旧版调用）。
func extractUserIDFromContext(c *gin.Context) string {
	// 1. AuthMiddleware 注入
	if uid, exists := c.Get("user_id"); exists {
		if s, ok := uid.(string); ok && s != "" {
			return s
		}
	}

	// 2. X-User-Id 请求头
	if uid := c.GetHeader("X-User-Id"); uid != "" {
		return uid
	}

	// 3. 兜底：匿名用户
	return "anonymous"
}