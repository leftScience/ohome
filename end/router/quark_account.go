package router

import (
	"ohome/api"

	"github.com/gin-gonic/gin"
)

func InitQuarkAccountRoutes() {
	RegisterRouter(func(rgPublic *gin.RouterGroup, rgAuth *gin.RouterGroup) {
		quarkAccountApi := api.NewQuarkAccountApi()
		rg := rgAuth.Group("/quarkAccount")
		{
			rg.GET("/status", quarkAccountApi.GetStatus)
			rg.PUT("/systemMode", quarkAccountApi.SetSystemMode)
			rg.PUT("/preferExclusive", quarkAccountApi.SetPreferExclusive)
		}
	})
}
