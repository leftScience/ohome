package router

import (
	"ohome/api"

	"github.com/gin-gonic/gin"
)

func InitAppMessageRoutes() {
	RegisterRouter(func(rgPublic *gin.RouterGroup, rgAuth *gin.RouterGroup) {
		_ = rgPublic
		messageApi := api.NewAppMessageApi()
		rg := rgAuth.Group("")
		{
			rg.GET("/appMessage/ws", messageApi.Subscribe)
			rg.POST("/appMessage/list", messageApi.GetList)
			rg.POST("/appMessage/read", messageApi.MarkRead)
			rg.POST("/appMessage/readAll", messageApi.MarkAllRead)
			rg.POST("/appMessage/sendSystem", messageApi.SendSystemMessage)
			rg.DELETE("/appMessage/:id", messageApi.Delete)
		}
	})
}
