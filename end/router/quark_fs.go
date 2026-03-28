package router

import (
	"ohome/api"
	"ohome/middleware"

	"github.com/gin-gonic/gin"
)

func InitQuarkFsRoutes() {
	RegisterRouter(func(rgPublic *gin.RouterGroup, rgAuth *gin.RouterGroup) {
		quarkFsApi := api.NewQuarkFsApi()

		// 公共路由（无需登录，供播放器/外部访问）
		rgQuarkPublic := rgPublic.Group("/quarkFs")
		rgQuarkPublic.Use(middleware.StreamAuth())
		{
			rgQuarkPublic.GET("/:application/files/stream", quarkFsApi.StreamQuarkFile)
			rgQuarkPublic.HEAD("/:application/files/stream", quarkFsApi.StreamQuarkFile)
		}

		rgQuark := rgAuth.Group("/quarkFs")
		{
			rgQuark.POST("/:application/files/list", quarkFsApi.GetQuarkFileList)
			rgQuark.GET("/:application/files/meta", quarkFsApi.GetQuarkFileMetadata)
			rgQuark.POST("/:application/files/rename", quarkFsApi.RenameQuarkFile)
			rgQuark.POST("/:application/files/move", quarkFsApi.MoveQuarkFile)
			rgQuark.POST("/:application/files/upload", quarkFsApi.UploadQuarkFile)
			rgQuark.DELETE("/:application/files", quarkFsApi.DeleteQuarkFile)
		}
	})
}
