package router

import (
	"ohome/api"

	"github.com/gin-gonic/gin"
)

func InitQuarkAutoSaveTaskRoutes() {
	RegisterRouter(func(rgPublic *gin.RouterGroup, rgAuth *gin.RouterGroup) {
		_ = rgPublic
		taskApi := api.NewQuarkAutoSaveTaskApi()

		rg := rgAuth.Group("/quarkAutoSaveTask")
		{
			rg.POST("/list", taskApi.GetList)
			rg.GET("/:id", taskApi.GetByID)
			rg.PUT("/add", taskApi.AddOrUpdate)
			rg.DELETE("/:id", taskApi.Delete)
			rg.POST("/run/:id", taskApi.RunOnce)
			rg.POST("/transfer", taskApi.TransferOnce)
			rg.POST("/share-preview", taskApi.SharePreview)
		}
	})
}
