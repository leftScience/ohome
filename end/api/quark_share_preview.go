package api

import (
	"ohome/service/dto"
	"ohome/utils"

	"github.com/gin-gonic/gin"
)

// SharePreview 预览夸克分享链接内的文件列表
func (a *QuarkAutoSaveTask) SharePreview(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	var previewDTO dto.QuarkSharePreviewDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &previewDTO}).GetErrors(); err != nil {
		return
	}
	result, err := quarkAutoSaveTaskService.SharePreview(&previewDTO, loginUser.ID)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}