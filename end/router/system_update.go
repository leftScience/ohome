package router

import (
	"ohome/api"

	"github.com/gin-gonic/gin"
)

func InitSystemUpdateRoutes() {
	RegisterRouter(func(rgPublic *gin.RouterGroup, rgAuth *gin.RouterGroup) {
		_ = rgPublic
		systemUpdateApi := api.NewSystemUpdateApi()
		rgSystem := rgAuth.Group("/system/update")
		{
			rgSystem.GET("/info", systemUpdateApi.Info)
			rgSystem.POST("/check", systemUpdateApi.Check)
			rgSystem.POST("/apply", systemUpdateApi.Apply)
			rgSystem.GET("/tasks/:taskId", systemUpdateApi.Task)
			rgSystem.POST("/rollback", systemUpdateApi.Rollback)
		}
	})
}
