package api

import (
	"ohome/model"
	"ohome/service/dto"
	"ohome/utils"
	"strings"

	"github.com/gin-gonic/gin"
)

const sensitiveConfigKeyQuarkCookies = "quark_cookies"
const sensitiveConfigKeyQuarkTVRefreshToken = "quark_tv_refresh_token"
const sensitiveConfigKeyQuarkTVDeviceID = "quark_tv_device_id"
const sensitiveConfigKeyQuarkTVQueryToken = "quark_tv_query_token"
const sensitiveConfigKeyQuarkSearchHTTPProxy = "quark_search_http_proxy"
const sensitiveConfigKeyQuarkSearchHTTPSProxy = "quark_search_https_proxy"
const sensitiveConfigKeyQuarkSearchChannels = "quark_search_channels"
const sensitiveConfigKeyQuarkSearchEnabledPlugins = "quark_search_enabled_plugins"
const sensitiveConfigKeyQuarkStreamWebProxyMode = "quark_fs_web_proxy_mode"

var sensitiveConfigKeys = map[string]struct{}{
	sensitiveConfigKeyQuarkCookies:              {},
	sensitiveConfigKeyQuarkTVRefreshToken:       {},
	sensitiveConfigKeyQuarkTVDeviceID:           {},
	sensitiveConfigKeyQuarkTVQueryToken:         {},
	sensitiveConfigKeyQuarkSearchHTTPProxy:      {},
	sensitiveConfigKeyQuarkSearchHTTPSProxy:     {},
	sensitiveConfigKeyQuarkSearchChannels:       {},
	sensitiveConfigKeyQuarkSearchEnabledPlugins: {},
	sensitiveConfigKeyQuarkStreamWebProxyMode:   {},
}

var readableSensitiveConfigKeys = map[string]struct{}{
	sensitiveConfigKeyQuarkStreamWebProxyMode: {},
}

type Config struct {
	BaseApi
}

func NewConfigApi() Config {
	return Config{
		BaseApi: NewBaseApi(),
	}
}

// GetConfigList 获取参数列表（分页）
func (config *Config) GetConfigList(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	var iConfigListDTO dto.ConfigListDTO
	if err := config.Request(RequestOptions{Ctx: c, DTO: &iConfigListDTO}).GetErrors(); err != nil {
		return
	}

	if !loginUser.IsSuperAdmin() {
		if !canReadConfig(loginUser, iConfigListDTO.Key) || containsUnreadableSensitiveConfigKeys(loginUser, iConfigListDTO.Keys) {
			utils.PermissionFail("无权限访问", c)
			return
		}
		iConfigListDTO.ExcludeKeys = unreadableSensitiveConfigKeyList(loginUser)
	}

	giConfigList, nTotal, err := configService.GetConfigList(&iConfigListDTO)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(gin.H{
		"records": giConfigList,
		"total":   nTotal,
	}, c)
}

// GetConfigById  根据id获取配置
func (config *Config) GetConfigById(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	var iCommonIDDTO dto.CommonIDDTO
	if err := config.Request(RequestOptions{Ctx: c, DTO: &iCommonIDDTO}).GetErrors(); err != nil {
		return
	}

	iConfig, err := configService.GetConfigById(&iCommonIDDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	if !canReadConfig(loginUser, iConfig.Key) {
		utils.PermissionFail("无权限访问", c)
		return
	}

	utils.OkWithData(iConfig, c)
}

func (config *Config) AddOrUpdateConfig(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	var iConfigUpdateDTO dto.ConfigUpdateDTO

	if err := config.Request(RequestOptions{Ctx: c, DTO: &iConfigUpdateDTO}).GetErrors(); err != nil {
		return
	}

	if !canWriteConfig(loginUser, iConfigUpdateDTO.Key) {
		utils.PermissionFail("无权限访问", c)
		return
	}
	if iConfigUpdateDTO.ID != 0 {
		currentConfig, err := configService.GetConfigById(&dto.CommonIDDTO{ID: iConfigUpdateDTO.ID})
		if err != nil {
			utils.FailWithMessage(err.Error(), c)
			return
		}
		if !canWriteConfig(loginUser, currentConfig.Key) {
			utils.PermissionFail("无权限访问", c)
			return
		}
	}

	err = configService.AddOrUpdateConfig(&iConfigUpdateDTO)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.Ok(c)
}

func (config *Config) DeleteConfig(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	var iCommonIDDTO dto.CommonIDDTO
	if err := config.Request(RequestOptions{Ctx: c, DTO: &iCommonIDDTO}).GetErrors(); err != nil {
		return
	}

	currentConfig, err := configService.GetConfigById(&iCommonIDDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	if !canWriteConfig(loginUser, currentConfig.Key) {
		utils.PermissionFail("无权限访问", c)
		return
	}

	err = configService.DeleteConfigById(&iCommonIDDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithMessage("删除成功!", c)
}

func isSensitiveConfigKey(key string) bool {
	_, exists := sensitiveConfigKeys[strings.TrimSpace(key)]
	return exists
}

func canReadSensitiveConfig(key string) bool {
	_, exists := readableSensitiveConfigKeys[strings.TrimSpace(key)]
	return exists
}

func canReadConfig(loginUser model.LoginUser, key string) bool {
	if !isSensitiveConfigKey(key) {
		return true
	}
	if loginUser.IsSuperAdmin() {
		return true
	}
	return canReadSensitiveConfig(key)
}

func canWriteConfig(loginUser model.LoginUser, key string) bool {
	if !isSensitiveConfigKey(key) {
		return true
	}
	return loginUser.IsSuperAdmin()
}

func containsUnreadableSensitiveConfigKeys(loginUser model.LoginUser, keys []string) bool {
	for _, key := range keys {
		if !canReadConfig(loginUser, key) {
			return true
		}
	}
	return false
}

func unreadableSensitiveConfigKeyList(loginUser model.LoginUser) []string {
	keys := make([]string, 0, len(sensitiveConfigKeys))
	for key := range sensitiveConfigKeys {
		if canReadConfig(loginUser, key) {
			continue
		}
		keys = append(keys, key)
	}
	return keys
}
