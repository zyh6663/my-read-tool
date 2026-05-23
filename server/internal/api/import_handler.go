package api

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"

	"purereader-server/internal/models"
	"purereader-server/internal/services"
	"purereader-server/pkg/database"
)

type ImportHandler struct{}

type importTask struct {
	Progress float64 `json:"progress"`
	Status   string  `json:"status"`
	Error    string  `json:"error,omitempty"`
	BookID   uint    `json:"book_id,omitempty"`
}

var importTasks = struct {
	sync.RWMutex
	m map[string]*importTask
}{m: map[string]*importTask{}}

func NewImportHandler() *ImportHandler { return &ImportHandler{} }

func (h *ImportHandler) Import(c *gin.Context) {
	var req struct {
		SourceID      uint   `json:"source_id"`
		BookID        string `json:"book_id"`
		ChapterRange  string `json:"chapter_range"`
		AutoAddToShelf bool   `json:"auto_add_to_shelf"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.SourceID == 0 || req.BookID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	taskID := strconv.FormatInt(time.Now().UnixNano(), 10)
	importTasks.Lock()
	importTasks.m[taskID] = &importTask{Progress: 0.01, Status: "running"}
	importTasks.Unlock()

	go h.runImport(taskID, importRequest{
		SourceID:       req.SourceID,
		BookID:         req.BookID,
		ChapterRange:   req.ChapterRange,
		UserID:         extractUserID(c),
		AutoAddToShelf: req.AutoAddToShelf,
	})
	c.JSON(http.StatusAccepted, gin.H{"data": gin.H{"task_id": taskID}})
}

type importRequest struct {
	SourceID      uint
	BookID        string
	ChapterRange  string
	UserID        string
	AutoAddToShelf bool
}

func (h *ImportHandler) runImport(taskID string, req importRequest) {
	setTask := func(progress float64, status string, errMsg string, bookID uint) {
		importTasks.Lock()
		t := importTasks.m[taskID]
		if t == nil {
			t = &importTask{}
			importTasks.m[taskID] = t
		}
		t.Progress = progress
		t.Status = status
		t.Error = errMsg
		t.BookID = bookID
		importTasks.Unlock()
	}

	detail, err := services.GetBookDetail(req.SourceID, req.BookID)
	if err != nil {
		setTask(1, "failed", err.Error(), 0)
		return
	}
	setTask(0.2, "running", "", 0)

	book := models.Book{
		Title:      detail.Title,
		Author:     detail.Author,
		CoverURL:   detail.CoverURL,
		FilePath:   fmt.Sprintf("online://%d/%s", req.SourceID, req.BookID),
		Format:     "txt",
		StorageType: "online",
		IsPrivate:  false,
		Content:    "",
		UserID:     req.UserID,
	}
	if err := database.DB.Create(&book).Error; err != nil {
		setTask(1, "failed", err.Error(), 0)
		return
	}
	setTask(0.35, "running", "", book.ID)

	var builder strings.Builder
	builder.WriteString(detail.Title + "\n")
	builder.WriteString(detail.Author + "\n\n")

	for i, ch := range detail.Chapters {
		content, err := services.GetChapterContent(req.SourceID, req.BookID, ch.URL)
		if err != nil {
			content = ""
		}
		builder.WriteString(fmt.Sprintf("%s\n%s\n\n", ch.Title, content))
		setTask(0.35+0.6*float64(i+1)/float64(max(1, len(detail.Chapters))), "running", "", book.ID)
	}
	book.Content = builder.String()
	if err := database.DB.Save(&book).Error; err != nil {
		setTask(1, "failed", err.Error(), 0)
		return
	}
	setTask(1, "completed", "", book.ID)

	// Auto-add to shelf if requested
	if req.AutoAddToShelf && req.UserID != "" {
		var existing models.BookShelf
		if err := database.DB.Where("user_id = ? AND book_id = ?", req.UserID, book.ID).First(&existing).Error; err != nil {
			shelf := models.BookShelf{
				UserID: req.UserID,
				BookID: book.ID,
			}
			if err := database.DB.Create(&shelf).Error; err != nil {
				fmt.Printf("import_handler: failed to auto-add book %d to shelf for user %s: %v\n", book.ID, req.UserID, err)
			}
		}
	}
}

func (h *ImportHandler) Progress(c *gin.Context) {
	taskID := c.Query("task_id")
	importTasks.RLock()
	t := importTasks.m[taskID]
	importTasks.RUnlock()
	if t == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "task not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"task_id": taskID, "progress": t.Progress, "status": t.Status, "error": t.Error, "book_id": t.BookID}})
}

func max(a, b int) int {
	if a > b { return a }
	return b
}
