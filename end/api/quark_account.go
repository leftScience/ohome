package api

import (
	"ohome/service"
	"ohome/utils"
	"strings"

	"github.com/gin-gonic/gin"
)

type QuarkAccount struct {
	BaseApi
}

func NewQuarkAccountApi() QuarkAccount {
	return QuarkAccount{BaseApi: NewBaseApi()}
}

type quarkAccountSystemModeDTO struct {
	Mode string `json:"mode"`
}

type quarkAccountPreferExclusiveDTO struct {
	PreferExclusive bool `json:"preferExclusive"`
}

func (a *QuarkAccount) GetStatus(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(service.BuildQuarkAccountStatusExport(loginUser), c)
}

func (a *QuarkAccount) SetSystemMode(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	var req quarkAccountSystemModeDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &req}).GetErrors(); err != nil {
		return
	}
	mode := strings.TrimSpace(req.Mode)
	if mode == "" {
		utils.FailWithMessage("共享状态不能为空", c)
		return
	}
	if err := service.SetQuarkAccountSystemModeExport(mode); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithMessage("夸克共享状态已更新", c)
}

func (a *QuarkAccount) SetPreferExclusive(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	var req quarkAccountPreferExclusiveDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &req}).GetErrors(); err != nil {
		return
	}
	if err := service.SetQuarkPreferExclusiveExport(loginUser.ID, req.PreferExclusive); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithMessage("独享偏好已更新", c)
}
