package api

import (
	"ohome/service/dto"
	"ohome/utils"

	"github.com/gin-gonic/gin"
)

type QuarkConfig struct {
	BaseApi
}

func NewQuarkConfigApi() QuarkConfig {
	return QuarkConfig{
		BaseApi: NewBaseApi(),
	}
}

func (a *QuarkConfig) GetQuarkConfigList(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	var listDTO dto.QuarkConfigListDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &listDTO}).GetErrors(); err != nil {
		return
	}

	configs, total, err := quarkConfigService.GetQuarkConfigList(&listDTO, loginUser.ID)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(gin.H{
		"records": configs,
		"total":   total,
	}, c)
}

func (a *QuarkConfig) GetQuarkConfigByApplication(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	var applicationDTO dto.QuarkApplicationDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &applicationDTO}).GetErrors(); err != nil {
		return
	}

	config, err := quarkConfigService.GetQuarkConfigByApplication(&applicationDTO, loginUser.ID)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(config, c)
}

func (a *QuarkConfig) CreateQuarkConfig(c *gin.Context) {
	var createDTO dto.QuarkConfigCreateDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &createDTO}).GetErrors(); err != nil {
		return
	}

	config, err := quarkConfigService.CreateQuarkConfig(&createDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(config, c)
}

func (a *QuarkConfig) UpdateQuarkConfig(c *gin.Context) {
	var updateDTO dto.QuarkConfigUpdateDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &updateDTO}).GetErrors(); err != nil {
		return
	}

	err := quarkConfigService.UpdateQuarkConfig(&updateDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.Ok(c)
}

func (a *QuarkConfig) DeleteQuarkConfig(c *gin.Context) {
	var applicationDTO dto.QuarkApplicationDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &applicationDTO}).GetErrors(); err != nil {
		return
	}

	if err := quarkConfigService.DeleteQuarkConfig(&applicationDTO); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithMessage("删除成功", c)
}
