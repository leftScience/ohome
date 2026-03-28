package middleware

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	puresqlite "github.com/glebarez/sqlite"
	"github.com/spf13/viper"
	"gorm.io/gorm"
	"gorm.io/gorm/schema"

	"ohome/global"
	"ohome/model"
	"ohome/utils"
)

func TestStreamAuthRejectsMissingToken(t *testing.T) {
	restore := setupStreamAuthTestEnv(t)
	defer restore()

	router := newStreamAuthTestRouter()
	req := httptest.NewRequest(http.MethodGet, "/stream", nil)
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.Code, http.StatusUnauthorized)
	}
}

func TestStreamAuthAcceptsAccessTokenFromQuery(t *testing.T) {
	restore := setupStreamAuthTestEnv(t)
	defer restore()

	token, err := utils.GenerateAccessToken(1, "tester")
	if err != nil {
		t.Fatalf("GenerateAccessToken() error = %v", err)
	}

	router := newStreamAuthTestRouter()
	req := httptest.NewRequest(http.MethodGet, "/stream?access_token="+url.QueryEscape(token), nil)
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", resp.Code, http.StatusNoContent)
	}
}

func TestStreamAuthRejectsRefreshToken(t *testing.T) {
	restore := setupStreamAuthTestEnv(t)
	defer restore()

	token, err := utils.GenerateRefreshToken(1, "tester")
	if err != nil {
		t.Fatalf("GenerateRefreshToken() error = %v", err)
	}

	router := newStreamAuthTestRouter()
	req := httptest.NewRequest(http.MethodGet, "/stream?access_token="+url.QueryEscape(token), nil)
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.Code, http.StatusUnauthorized)
	}
}

func newStreamAuthTestRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	streamGroup := router.Group("/stream")
	streamGroup.Use(StreamAuth())
	streamGroup.GET("", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})
	return router
}

func setupStreamAuthTestEnv(t *testing.T) func() {
	t.Helper()

	previousDB := global.DB
	signKey := viper.Get("jwt.signKey")
	accessExpires := viper.Get("jwt.accessTokenExpires")
	refreshExpires := viper.Get("jwt.refreshTokenExpires")

	db := newStreamAuthTestDB(t)
	global.DB = db
	viper.Set("jwt.signKey", "stream-auth-test-key")
	viper.Set("jwt.accessTokenExpires", 30)
	viper.Set("jwt.refreshTokenExpires", 30)

	return func() {
		global.DB = previousDB
		viper.Set("jwt.signKey", signKey)
		viper.Set("jwt.accessTokenExpires", accessExpires)
		viper.Set("jwt.refreshTokenExpires", refreshExpires)
	}
}

func newStreamAuthTestDB(t *testing.T) *gorm.DB {
	t.Helper()

	dsn := "file:stream_auth_" + time.Now().Format("20060102150405.000000000") + "?mode=memory&cache=shared"
	db, err := gorm.Open(puresqlite.Open(dsn), &gorm.Config{
		NamingStrategy: schema.NamingStrategy{
			TablePrefix:   "sys_",
			SingularTable: true,
		},
	})
	if err != nil {
		t.Fatalf("gorm.Open() error = %v", err)
	}

	if err := db.AutoMigrate(&model.Role{}, &model.User{}); err != nil {
		t.Fatalf("AutoMigrate() error = %v", err)
	}

	role := model.Role{
		Name: "测试管理员",
		Code: model.RoleCodeSuperAdmin,
	}
	if err := db.Create(&role).Error; err != nil {
		t.Fatalf("Create(role) error = %v", err)
	}

	user := model.User{
		CommonModel: model.CommonModel{ID: 1},
		Name:        "tester",
		Password:    "123456",
		RoleID:      role.ID,
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("Create(user) error = %v", err)
	}

	return db
}
