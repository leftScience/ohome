package api

import (
	"errors"
	"ohome/global/constants"
	"ohome/model"
	"ohome/utils"

	"github.com/gin-gonic/gin"
)

func getLoginUser(c *gin.Context) (model.LoginUser, error) {
	value, ok := c.Get(constants.LOGIN_USER)
	if !ok {
		return model.LoginUser{}, errors.New("用户信息不存在")
	}
	loginUser, ok := value.(model.LoginUser)
	if !ok || loginUser.ID == 0 {
		return model.LoginUser{}, errors.New("用户信息不存在")
	}
	return loginUser, nil
}

func requireSuperAdmin(c *gin.Context) (model.LoginUser, bool) {
	return requireSuperAdminWithMessage(c, "无权限访问")
}

func requireSuperAdminWithMessage(c *gin.Context, message string) (model.LoginUser, bool) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return model.LoginUser{}, false
	}
	if !loginUser.IsSuperAdmin() {
		utils.PermissionFail(message, c)
		return model.LoginUser{}, false
	}
	return loginUser, true
}
