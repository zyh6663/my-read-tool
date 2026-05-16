package api

import (
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"purereader-server/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var jwtSecret = []byte("purereader-secret-key-change-in-production")

// JWT Claims 结构
type Claims struct {
	UserID uint `json:"user_id"`
	jwt.RegisteredClaims
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

// generateToken 为用户生成 JWT Token，有效期 7 天
func generateToken(userID uint) (string, error) {
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// parseToken 解析 JWT Token 并返回 userID
func parseToken(tokenString string) (uint, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return jwtSecret, nil
	})
	if err != nil {
		return 0, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims.UserID, nil
	}

	return 0, jwt.ErrSignatureInvalid
}

// AuthHandler 认证相关 API 处理器
type AuthHandler struct {
	DB *gorm.DB
}

// NewAuthHandler 创建 AuthHandler 实例
func NewAuthHandler(db *gorm.DB) *AuthHandler {
	return &AuthHandler{DB: db}
}

// Register 用户注册
func (h *AuthHandler) Register(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required"`
		Password string `json:"password" binding:"required"`
		Nickname string `json:"nickname"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数无效"})
		return
	}

	email := normalizeEmail(req.Email)
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	if !emailRegex.MatchString(email) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "邮箱格式不正确"})
		return
	}

	if len(req.Password) < 8 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "密码长度不能少于8位"})
		return
	}

	var existingUser models.User
	if err := h.DB.Where("LOWER(email) = ?", email).First(&existingUser).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "该邮箱已被注册"})
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "密码加密失败"})
		return
	}

	user := models.User{Email: email, PasswordHash: string(hashedPassword), Nickname: strings.TrimSpace(req.Nickname)}
	if err := h.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "用户创建失败"})
		return
	}

	token, err := generateToken(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "令牌生成失败"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"token": token, "user": gin.H{"id": user.ID, "email": user.Email, "nickname": user.Nickname}})
}

// Login 用户登录
func (h *AuthHandler) Login(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required"`
		Password string `json:"password" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数无效"})
		return
	}

	email := normalizeEmail(req.Email)
	var user models.User
	if err := h.DB.Where("LOWER(email) = ?", email).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "邮箱或密码错误"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "邮箱或密码错误"})
		return
	}

	token, err := generateToken(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "令牌生成失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": token, "user": gin.H{"id": user.ID, "email": user.Email, "nickname": user.Nickname}})
}

func (h *AuthHandler) GetMe(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未认证"})
		return
	}

	var userID uint
	switch v := userIDVal.(type) {
	case uint:
		userID = v
	case string:
		parsed, err := strconv.ParseUint(v, 10, 64)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "认证信息无效"})
			return
		}
		userID = uint(parsed)
	default:
		c.JSON(http.StatusUnauthorized, gin.H{"error": "认证信息无效"})
		return
	}

	var user models.User
	if err := h.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": gin.H{"id": user.ID, "email": user.Email, "nickname": user.Nickname}})
}

func (h *AuthHandler) Migrate(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required"`
		Password string `json:"password" binding:"required"`
		UUID     string `json:"uuid" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数无效"})
		return
	}

	email := normalizeEmail(req.Email)
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	if !emailRegex.MatchString(email) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "邮箱格式不正确"})
		return
	}
	if len(req.Password) < 8 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "密码长度不能少于8位"})
		return
	}

	var existingUser models.User
	if err := h.DB.Where("LOWER(email) = ?", email).First(&existingUser).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "该邮箱已被注册"})
		return
	}

	err := h.DB.Transaction(func(tx *gorm.DB) error {
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
		if err != nil {
			return err
		}
		user := models.User{Email: email, PasswordHash: string(hashedPassword)}
		if err := tx.Create(&user).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.Progress{}).Where("user_id = ?", req.UUID).Update("user_id", user.ID).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.BookShelf{}).Where("user_id = ?", req.UUID).Update("user_id", user.ID).Error; err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "迁移失败: " + err.Error()})
		return
	}

	if err := h.DB.Where("LOWER(email) = ?", email).First(&existingUser).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户失败"})
		return
	}
	token, err := generateToken(existingUser.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "令牌生成失败"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"token": token, "user": gin.H{"id": existingUser.ID, "email": existingUser.Email, "nickname": existingUser.Nickname}})
}
