package router

import (
	"ohome/api"

	"github.com/gin-gonic/gin"
)

func InitUserRoutes() {
	RegisterRouter(func(rgPublic *gin.RouterGroup, rgAuth *gin.RouterGroup) {
		userApi := api.NewUserApi()

		// 不需要鉴权的
		rgPublic.POST("/login", func(context *gin.Context) {
			userApi.Login(context)
		})
		rgPublic.POST("/register", func(context *gin.Context) {
			userApi.Register(context)
		})
		rgPublic.GET("/register/status", func(context *gin.Context) {
			userApi.GetRegisterStatus(context)
		})
		rgPublic.GET("/refreshToken", func(context *gin.Context) {
			userApi.RefreshToken(context)
		})

		// 需要鉴权
		rgAuthUser := rgAuth.Group("/user")
		{
			rgAuthUser.GET("/profile", userApi.GetProfile)
			rgAuthUser.GET("/password/status", userApi.GetPasswordStatus)
			rgAuthUser.POST("/add", userApi.AddUser)
			rgAuthUser.DELETE("/:id", userApi.DeleteUserById)
			rgAuthUser.PUT("/:id", userApi.UpdateUser)
			rgAuthUser.GET("/:id", userApi.GetUserById)
			rgAuthUser.POST("/list", userApi.GetUserList)
			rgAuthUser.POST("/updateAvatar", userApi.UpdateAvatar)
			rgAuthUser.POST("/changePwd", userApi.ChangePassword)
			rgAuthUser.POST("/resetPwd", userApi.ResetPassword)
		}

	})
}
