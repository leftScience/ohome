package utils

import (
	"errors"
	"fmt"
	"net/http"
	"reflect"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

type Response struct {
	Code int    `json:"code"`
	Data any    `json:"data"`
	Msg  string `json:"msg"`
}

const (
	ERROR           = 500
	TOKENERROR      = 401
	PERMISSIONERROR = 403
	SUCCESS         = 200
)

func Result(code int, data interface{}, msg string, c *gin.Context) {
	c.JSON(http.StatusOK, Response{
		code,
		data,
		msg,
	})
}

func Ok(c *gin.Context) {
	Result(SUCCESS, map[string]interface{}{}, "成功", c)
}

func OkWithMessage(message string, c *gin.Context) {
	Result(SUCCESS, map[string]interface{}{}, message, c)
}

func OkWithData(data interface{}, c *gin.Context) {
	Result(SUCCESS, data, "成功", c)
}

func OkWithDetailed(data interface{}, message string, c *gin.Context) {
	Result(SUCCESS, data, message, c)
}

func FailWithMessage(message string, c *gin.Context) {
	c.Abort()
	Result(ERROR, map[string]interface{}{}, message, c)
}

func FailWithDetailed(data interface{}, message string, c *gin.Context) {
	c.Abort()
	Result(ERROR, data, message, c)
}

func TokenFail(c *gin.Context) {
	c.Abort()
	Result(TOKENERROR, map[string]interface{}{}, "", c)
}

func PermissionFail(message string, c *gin.Context) {
	c.Abort()
	Result(PERMISSIONERROR, map[string]interface{}{}, message, c)
}

// ParseValidateErrors 解析错误信息 返回自定义错误信息
func ParseValidateErrors(errs error, target any) error {
	var errResult error

	errValidation, ok := errs.(validator.ValidationErrors)
	if !ok {
		return errs
	}

	// 通过反射获取指针指向元素的类型对象
	fields := reflect.TypeOf(target).Elem()

	for _, fieldErr := range errValidation {
		field, _ := fields.FieldByName(fieldErr.Field())
		errMsgTag := fmt.Sprintf("%s_err", fieldErr.Tag())
		errMsg := field.Tag.Get(errMsgTag)
		if errMsg == "" {
			errMsg = field.Tag.Get("massage")
		}
		if errMsg == "" {
			errMsg = fmt.Sprintf("%s 字段校验失败（规则：%s）", fieldErr.Field(), fieldErr.Tag())
		}
		errResult = AppendError(errResult, errors.New(errMsg))
	}
	return errResult
}
