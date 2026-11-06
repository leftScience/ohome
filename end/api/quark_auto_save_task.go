package api

import (
	"ohome/service/dto"
	"ohome/utils"

	"github.com/gin-gonic/gin"
)

type QuarkAutoSaveTask struct {
	BaseApi
}

func NewQuarkAutoSaveTaskApi() QuarkAutoSaveTask {
	return QuarkAutoSaveTask{BaseApi: NewBaseApi()}
}

// GetList 获取任务列表（分页）
func (a *QuarkAutoSaveTask) GetList(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	var listDTO dto.QuarkAutoSaveTaskListDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &listDTO}).GetErrors(); err != nil {
		return
	}
	tasks, total, err := quarkAutoSaveTaskService.GetList(&listDTO, loginUser.ID)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithData(gin.H{"records": tasks, "total": total}, c)
}

func (a *QuarkAutoSaveTask) GetByID(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	var idDTO dto.CommonIDDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &idDTO}).GetErrors(); err != nil {
		return
	}
	task, err := quarkAutoSaveTaskService.GetByID(&idDTO, loginUser.ID)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithData(task, c)
}

func (a *QuarkAutoSaveTask) AddOrUpdate(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	var updateDTO dto.QuarkAutoSaveTaskUpdateDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &updateDTO}).GetErrors(); err != nil {
		return
	}
	if err := quarkAutoSaveTaskService.AddOrUpdate(&updateDTO, loginUser.ID); err != nil {
		failQuarkError(err, c)
		return
	}
	utils.Ok(c)
}

func (a *QuarkAutoSaveTask) Delete(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	var idDTO dto.CommonIDDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &idDTO}).GetErrors(); err != nil {
		return
	}
	if err := quarkAutoSaveTaskService.DeleteByID(&idDTO, loginUser.ID); err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithMessage("删除成功", c)
}

func (a *QuarkAutoSaveTask) RunOnce(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	var idDTO dto.CommonIDDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &idDTO}).GetErrors(); err != nil {
		return
	}
	task, err := quarkAutoSaveTaskService.GetByID(&idDTO, loginUser.ID)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	transferTask, err := quarkAutoSaveTaskService.RunOnce(task, loginUser.ID)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithData(gin.H{
		"taskId": transferTask.ID,
		"status": transferTask.Status,
	}, c)
}

func (a *QuarkAutoSaveTask) TransferOnce(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	var transferDTO dto.QuarkAutoSaveTransferDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &transferDTO}).GetErrors(); err != nil {
		return
	}
	transferTask, err := quarkAutoSaveTaskService.TransferOnce(&transferDTO, loginUser.ID)
	if err != nil {
		failQuarkError(err, c)
		return
	}
	utils.OkWithData(gin.H{
		"taskId": transferTask.ID,
		"status": transferTask.Status,
	}, c)
}
