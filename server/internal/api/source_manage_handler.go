package api

import (
	"encoding/json"
	"net/http"

	"purereader-server/internal/models"
	"purereader-server/internal/services"
	"purereader-server/pkg/database"

	"github.com/gin-gonic/gin"
)

type sourceRequest struct {
	Name      string `json:"name"`
	BaseURL   string `json:"base_url"`
	RuleJSON  string `json:"rule_json"`
	Enabled   bool   `json:"enabled"`
	Priority  int    `json:"priority"`
	IsBuiltin bool   `json:"is_builtin"`
}

func respondData(c *gin.Context, status int, data any) {
	c.JSON(status, gin.H{"data": data, "error": ""})
}

func respondError(c *gin.Context, status int, msg string) {
	c.JSON(status, gin.H{"data": nil, "error": msg})
}

func ListSources(c *gin.Context) {
	var sources []models.BookSource
	if err := database.DB.Where("user_id = ?", extractUserID(c)).Order("priority desc, id desc").Find(&sources).Error; err != nil {
		respondError(c, http.StatusInternalServerError, err.Error())
		return
	}
	respondData(c, http.StatusOK, sources)
}

func ImportSource(c *gin.Context) {
	var req sourceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "请求体格式错误")
		return
	}
	if err := services.ValidateSourceRule(req.RuleJSON); err != nil {
		respondError(c, http.StatusBadRequest, err.Error())
		return
	}
	var existing models.BookSource
	if err := database.DB.Where("base_url = ? AND user_id = ?", req.BaseURL, extractUserID(c)).First(&existing).Error; err == nil {
		respondError(c, http.StatusConflict, "来源已存在")
		return
	}
	item := models.BookSource{Name: req.Name, BaseURL: req.BaseURL, RuleJSON: req.RuleJSON, Enabled: req.Enabled, Priority: req.Priority, IsBuiltin: req.IsBuiltin, UserID: extractUserID(c)}
	if err := database.DB.Create(&item).Error; err != nil {
		respondError(c, http.StatusInternalServerError, err.Error())
		return
	}
	respondData(c, http.StatusCreated, item)
}

func UpdateSource(c *gin.Context) {
	id := c.Param("id")
	var src models.BookSource
	if err := database.DB.First(&src, id).Error; err != nil {
		respondError(c, http.StatusNotFound, "来源不存在")
		return
	}
	if src.UserID != extractUserID(c) {
		respondError(c, http.StatusForbidden, "无权限修改此书源")
		return
	}
	if src.IsBuiltin {
		respondError(c, http.StatusForbidden, "内置书源不可编辑")
		return
	}
	var req sourceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "请求体格式错误")
		return
	}
	if req.BaseURL != src.BaseURL {
		var exists models.BookSource
		if err := database.DB.Where("base_url = ? AND id <> ? AND user_id = ?", req.BaseURL, src.ID, extractUserID(c)).First(&exists).Error; err == nil {
			respondError(c, http.StatusConflict, "base_url 已存在")
			return
		}
	}
	if err := services.ValidateSourceRule(req.RuleJSON); err != nil { respondError(c, http.StatusBadRequest, err.Error()); return }
	src.Name, src.BaseURL, src.RuleJSON, src.Enabled, src.Priority = req.Name, req.BaseURL, req.RuleJSON, req.Enabled, req.Priority
	if err := database.DB.Save(&src).Error; err != nil { respondError(c, http.StatusInternalServerError, err.Error()); return }
	respondData(c, http.StatusOK, src)
}

func DeleteSource(c *gin.Context) {
	id := c.Param("id")
	var src models.BookSource
	if err := database.DB.First(&src, id).Error; err != nil { respondError(c, http.StatusNotFound, "来源不存在"); return }
	if src.UserID != extractUserID(c) { respondError(c, http.StatusForbidden, "无权限删除此书源"); return }
	if src.IsBuiltin { respondError(c, http.StatusForbidden, "内置书源不可删除"); return }
	if err := database.DB.Delete(&src).Error; err != nil { respondError(c, http.StatusInternalServerError, err.Error()); return }
	respondData(c, http.StatusOK, gin.H{"deleted": true})
}

func TestSource(c *gin.Context) {
	var req sourceRequest
	if err := c.ShouldBindJSON(&req); err != nil { respondError(c, http.StatusBadRequest, "请求体格式错误"); return }
	if err := services.ValidateSourceRule(req.RuleJSON); err != nil { respondError(c, http.StatusBadRequest, err.Error()); return }
	// TODO: F11 source_engine.go 完成真实抓取/解析测试。
	respondData(c, http.StatusOK, gin.H{"passed": true, "message": "规则格式校验通过"})
}

func GetTemplate(c *gin.Context) {
	tpl := sourceRequest{Name: "示例书源", BaseURL: "https://example.com", RuleJSON: `{"base_url":"https://example.com"}`, Enabled: true, Priority: 0}
	b, _ := json.Marshal(tpl)
	c.Data(http.StatusOK, "application/json; charset=utf-8", b)
}
