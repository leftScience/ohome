package api

import (
	"ohome/service"
	"ohome/updater"
	"ohome/utils"

	"github.com/gin-gonic/gin"
	"github.com/spf13/viper"
)

type SystemUpdate struct {
	BaseApi
	service service.SystemUpdateService
}

func NewSystemUpdateApi() SystemUpdate {
	return SystemUpdate{BaseApi: NewBaseApi()}
}

func (a *SystemUpdate) Info(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	if !ensureSystemUpdateEnabled(c) {
		return
	}
	result, err := a.service.Info()
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func (a *SystemUpdate) Check(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	if !ensureSystemUpdateEnabled(c) {
		return
	}
	var req updater.CheckRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	result, err := a.service.Check(req)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func (a *SystemUpdate) Apply(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	if !ensureSystemUpdateEnabled(c) {
		return
	}
	var req updater.ApplyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	result, err := a.service.Apply(req)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func (a *SystemUpdate) Task(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	if !ensureSystemUpdateEnabled(c) {
		return
	}
	result, err := a.service.Task(c.Param("taskId"))
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func (a *SystemUpdate) Rollback(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	if !ensureSystemUpdateEnabled(c) {
		return
	}
	var req updater.RollbackRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	result, err := a.service.Rollback(req)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func ensureSystemUpdateEnabled(c *gin.Context) bool {
	if viper.GetBool("mode.develop") {
		utils.PermissionFail("开发环境已禁用后端更新功能", c)
		return false
	}
	return true
}
