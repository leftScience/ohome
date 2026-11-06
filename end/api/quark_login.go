package api

import (
	"ohome/model"
	"ohome/service"
	"ohome/utils"
	"strings"

	"github.com/gin-gonic/gin"
)

type QuarkLogin struct {
	BaseApi
}

func NewQuarkLoginApi() QuarkLogin {
	return QuarkLogin{
		BaseApi: NewBaseApi(),
	}
}

func (a *QuarkLogin) GetQuarkTVStatus(c *gin.Context) {
	loginUser, target, ok := requireQuarkCredentialManagerWithTarget(c)
	if !ok {
		return
	}

	status, err := quarkTVLoginService.GetStatus(loginUser.ID, target)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithData(status, c)
}

func (a *QuarkLogin) StartQuarkTVLogin(c *gin.Context) {
	loginUser, target, ok := requireQuarkCredentialManagerWithTarget(c)
	if !ok {
		return
	}

	result, err := quarkTVLoginService.StartLogin(c.Request.Context(), loginUser.ID, target)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithData(result, c)
}

func (a *QuarkLogin) PollQuarkTVLogin(c *gin.Context) {
	loginUser, target, ok := requireQuarkCredentialManagerWithTarget(c)
	if !ok {
		return
	}

	result, err := quarkTVLoginService.PollLogin(c.Request.Context(), loginUser.ID, target)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithData(result, c)
}

func requireQuarkCredentialManagerWithTarget(c *gin.Context) (model.LoginUser, string, bool) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return model.LoginUser{}, "", false
	}

	target := service.NormalizeQuarkCredentialTargetExport(strings.TrimSpace(c.Query("credentialTarget")))
	if !canAccessQuarkCredentialAPI(loginUser, target) {
		utils.PermissionFail("当前模式下无夸克登录权限", c)
		return model.LoginUser{}, "", false
	}
	return loginUser, target, true
}
