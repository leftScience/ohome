package api

import (
	"ohome/service/dto"
	"ohome/utils"

	"github.com/gin-gonic/gin"
)

type QuarkTransferTask struct {
	BaseApi
}

func NewQuarkTransferTaskApi() QuarkTransferTask {
	return QuarkTransferTask{BaseApi: NewBaseApi()}
}

func (a *QuarkTransferTask) GetList(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	var listDTO dto.QuarkTransferTaskListDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &listDTO}).GetErrors(); err != nil {
		return
	}
	records, total, err := quarkTransferTaskService.GetList(&listDTO, loginUser.ID)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithData(gin.H{"records": records, "total": total}, c)
}

func (a *QuarkTransferTask) Delete(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	var idDTO dto.CommonIDDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &idDTO}).GetErrors(); err != nil {
		return
	}
	if err := quarkTransferTaskService.DeleteByID(&idDTO, loginUser.ID); err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithMessage("删除成功", c)
}
