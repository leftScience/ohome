package api

import (
	"errors"
	"ohome/model"
	"ohome/service"
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
const sensitiveConfigKeyQuarkSearchWebEngines = "quark_search_web_engines"
const sensitiveConfigKeyQuarkStreamWebProxyMode = "quark_fs_web_proxy_mode"
const sensitiveConfigKeyQuarkAccountShareMode = "quark_account_share_mode"

var sensitiveConfigKeys = map[string]struct{}{
	sensitiveConfigKeyQuarkCookies:              {},
	sensitiveConfigKeyQuarkTVRefreshToken:       {},
	sensitiveConfigKeyQuarkTVDeviceID:           {},
	sensitiveConfigKeyQuarkTVQueryToken:         {},
	sensitiveConfigKeyQuarkSearchHTTPProxy:      {},
	sensitiveConfigKeyQuarkSearchHTTPSProxy:     {},
	sensitiveConfigKeyQuarkSearchChannels:       {},
	sensitiveConfigKeyQuarkSearchEnabledPlugins: {},
	sensitiveConfigKeyQuarkSearchWebEngines:     {},
	sensitiveConfigKeyQuarkStreamWebProxyMode:   {},
	sensitiveConfigKeyQuarkAccountShareMode:     {},
}

var readableSensitiveConfigKeys = map[string]struct{}{
	sensitiveConfigKeyQuarkStreamWebProxyMode: {},
	sensitiveConfigKeyQuarkAccountShareMode:   {},
	sensitiveConfigKeyQuarkSearchWebEngines:   {},
}

var quarkCredentialConfigKeys = map[string]struct{}{
	sensitiveConfigKeyQuarkCookies:        {},
	sensitiveConfigKeyQuarkTVRefreshToken: {},
	sensitiveConfigKeyQuarkTVDeviceID:     {},
	sensitiveConfigKeyQuarkTVQueryToken:   {},
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

	if key := strings.TrimSpace(iConfigListDTO.Key); key != "" && isQuarkCredentialConfigKey(key) {
		target := service.NormalizeQuarkCredentialTargetExport(iConfigListDTO.CredentialTarget)
		if !canAccessQuarkCredentialAPI(loginUser, target) {
			utils.PermissionFail("无权限访问", c)
			return
		}
		item, ok, err := service.GetQuarkCredentialConfigAsModel(loginUser.ID, key, target)
		if err != nil {
			utils.FailWithMessage(err.Error(), c)
			return
		}
		records := []model.Config{}
		if ok {
			records = append(records, item)
		}
		utils.OkWithData(gin.H{
			"records": records,
			"total":   int64(len(records)),
		}, c)
		return
	}

	if !loginUser.IsSuperAdmin() {
		// 普通用户（含独享）一律看不到全局 sys_config 里的夸克凭证行
		if containsUnreadableSensitiveConfigKeys(loginUser, iConfigListDTO.Keys) ||
			(strings.TrimSpace(iConfigListDTO.Key) != "" && !canReadConfig(loginUser, iConfigListDTO.Key)) {
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

	key := strings.TrimSpace(iConfigUpdateDTO.Key)
	// 夸克凭证按 credentialTarget 决定落库位置（sys_config 或 user_config），
	// 请求里的 ID 可能来自 user_config，不能拿去查全局配置做权限判断。
	if key != "" && isQuarkCredentialConfigKey(key) {
		if err := saveQuarkCredentialConfig(loginUser, &iConfigUpdateDTO, key); err != nil {
			if code := service.QuarkErrorCode(err); code != "" {
				utils.FailWithReason(code, service.QuarkErrorMessage(err), c)
				return
			}
			utils.PermissionFail(err.Error(), c)
			return
		}
		utils.Ok(c)
		return
	}

	if iConfigUpdateDTO.ID != 0 {
		currentConfig, err := configService.GetConfigById(&dto.CommonIDDTO{ID: iConfigUpdateDTO.ID})
		if err != nil {
			utils.FailWithMessage(err.Error(), c)
			return
		}
		if key == "" {
			key = currentConfig.Key
			iConfigUpdateDTO.Key = currentConfig.Key
		}
		if !canWriteConfig(loginUser, currentConfig.Key) || !canWriteConfig(loginUser, key) {
			utils.PermissionFail("无权限访问", c)
			return
		}
	}

	if !canWriteConfig(loginUser, key) {
		utils.PermissionFail("无权限访问", c)
		return
	}

	if key == sensitiveConfigKeyQuarkAccountShareMode {
		if err := service.SetQuarkAccountSystemModeExport(iConfigUpdateDTO.Value); err != nil {
			utils.FailWithMessage(err.Error(), c)
			return
		}
		utils.Ok(c)
		return
	}

	err = configService.AddOrUpdateConfig(&iConfigUpdateDTO)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.Ok(c)
}

// saveQuarkCredentialConfig 按 credentialTarget 落库夸克凭证，不依赖全局 sys_config 主键。
func saveQuarkCredentialConfig(loginUser model.LoginUser, update *dto.ConfigUpdateDTO, key string) error {
	target := service.NormalizeQuarkCredentialTargetExport(update.CredentialTarget)
	if !canAccessQuarkCredentialAPI(loginUser, target) {
		return errors.New("无权限访问")
	}
	// 非超管不允许借全局 ID 改写全局共享凭证
	if target != service.QuarkCredentialTargetPersonal && !loginUser.IsSuperAdmin() {
		usePersonal, err := service.ResolveQuarkCredentialUsePersonalExport(loginUser.ID, target)
		if err != nil {
			return err
		}
		if !usePersonal {
			return errors.New("无权限访问")
		}
	}
	// 显式 personal 在共享模式下会被解析器拒绝，这里给出可读文案
	if _, err := service.ResolveQuarkCredentialUsePersonalExport(loginUser.ID, target); err != nil {
		return err
	}
	return service.SaveQuarkCredentialConfig(loginUser.ID, update, target)
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
	if isQuarkCredentialConfigKey(currentConfig.Key) {
		// 全局凭证行仅超管可删；独享用户只能删自己的 user_config，不能借全局 id 删共享号
		if !loginUser.IsSuperAdmin() {
			utils.PermissionFail("无权限删除全局夸克凭证", c)
			return
		}
	} else if !canWriteConfig(loginUser, currentConfig.Key) {
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

func isQuarkCredentialConfigKey(key string) bool {
	_, exists := quarkCredentialConfigKeys[strings.TrimSpace(key)]
	return exists
}

func canReadSensitiveConfig(key string) bool {
	_, exists := readableSensitiveConfigKeys[strings.TrimSpace(key)]
	return exists
}

func canReadConfig(loginUser model.LoginUser, key string) bool {
	key = strings.TrimSpace(key)
	if key == "" {
		return true
	}
	if isQuarkCredentialConfigKey(key) {
		// 全局 sys_config 凭证仅超管可读；独享用户走 key 过滤 + GetQuarkCredentialConfigAsModel
		return loginUser.IsSuperAdmin()
	}
	if !isSensitiveConfigKey(key) {
		return true
	}
	if loginUser.IsSuperAdmin() {
		return true
	}
	return canReadSensitiveConfig(key)
}

func canWriteConfig(loginUser model.LoginUser, key string) bool {
	key = strings.TrimSpace(key)
	if isQuarkCredentialConfigKey(key) {
		// 全局凭证写/删：仅超管。独享用户的写入走 SaveQuarkCredentialConfig(personal)。
		return loginUser.IsSuperAdmin()
	}
	if key == sensitiveConfigKeyQuarkAccountShareMode {
		return loginUser.IsSuperAdmin()
	}
	if !isSensitiveConfigKey(key) {
		return true
	}
	return loginUser.IsSuperAdmin()
}

// canAccessQuarkCredentialAPI 独享用户或超管可访问模式化凭证 API；
// target=shared 时仅超管可维护全局共享凭证；
// target=personal 必须在独享模式下才有意义（共享模式运行时只读全局凭证）。
func canAccessQuarkCredentialAPI(loginUser model.LoginUser, target string) bool {
	return service.CanAccessQuarkCredentialTargetExport(loginUser, target)
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
