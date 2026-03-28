package router

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	_ "ohome/docs"
	"ohome/global"
	"ohome/middleware"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"github.com/go-playground/validator/v10"
	"github.com/spf13/viper"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

type IFnRegisterRoute = func(rgPublic *gin.RouterGroup, rgAuth *gin.RouterGroup)

var (
	gFnRouters []IFnRegisterRoute
)

func RegisterRouter(fn IFnRegisterRoute) {
	if fn == nil {
		return
	}
	gFnRouters = append(gFnRouters, fn)
}

func InitRouter() {
	// 创建上下文
	ctx, cancelCtx := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancelCtx()

	r := gin.Default()
	//加载跨域插件
	r.Use(middleware.Cors())

	rgPublic := r.Group("api/v1/public")
	rgAuth := r.Group("api/v1")

	//使用中间件
	rgAuth.Use(middleware.Auth())

	initBasePlatformRoutes()
	initCustomValidator()

	for _, item := range gFnRouters {
		item(rgPublic, rgAuth)
	}

	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// 获取端口号
	port := strings.TrimSpace(viper.GetString("server.port"))
	if port == "" {
		port = "8999"
	}

	server := &http.Server{
		Addr:    fmt.Sprintf(":%s", port),
		Handler: r,
	}

	fmt.Printf("[GIN-SUCCESS] Server is listening on port %s...\n", port)

	go func() {
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			global.Logger.Errorf("Start Server Error: %s", err.Error())
			return
		}
	}()

	<-ctx.Done()

	ctx, cancelShotDown := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelShotDown()

	if err := server.Shutdown(ctx); err != nil {
		global.Logger.Errorf("Stop Server Error: %s", err.Error())
	}
}

// 初始基础平台的路由
func initBasePlatformRoutes() {
	InitDiscoveryRoutes()
	InitUserRoutes()
	InitConfigRoutes()
	InitQuarkLoginRoutes()
	InitTodoRoutes()
	InitDictRoutes()
	InitFileRoutes()
	InitQuarkConfigRoutes()
	InitQuarkFsRoutes()
	InitUserMediaHistoryRoutes()
	InitDoubanRoutes()
	InitPansouRoutes()
	InitQuarkAutoSaveTaskRoutes()
	InitQuarkTransferTaskRoutes()
	InitDropsItemRoutes()
	InitDropsEventRoutes()
	InitAppMessageRoutes()
	InitSystemUpdateRoutes()
}

// 初始化自定义校验器
func initCustomValidator() {
	if v, ok := binding.Validator.Engine().(*validator.Validate); ok {
		err := v.RegisterValidation("t_custom_validator", func(fl validator.FieldLevel) bool {
			if value, ok := fl.Field().Interface().(string); ok {
				global.Logger.Info(value)
				if value != "" && 0 == strings.Index(value, "a") {
					return true
				}
			}

			return false
		})
		if err != nil {
			return
		}
	}
}
