package api

import (
	"ohome/service"
	"ohome/utils"

	"github.com/gin-gonic/gin"
)

// failQuarkError 统一输出夸克凭证类错误。
// 业务码走响应体顶层 reason 字段，前端按码分支，不再依赖错误文案匹配。
func failQuarkError(err error, c *gin.Context) {
	if err == nil {
		return
	}
	if code := service.QuarkErrorCode(err); code != "" {
		utils.FailWithReason(code, service.QuarkErrorMessage(err), c)
		return
	}
	utils.FailWithMessage(err.Error(), c)
}
