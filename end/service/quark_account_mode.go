package service

import (
	"errors"
	"ohome/global"
	"ohome/model"
	"ohome/service/dto"
	"strings"
	"sync"

	"gorm.io/gorm"
)

const (
	QuarkAccountShareModeConfigKey = "quark_account_share_mode"
	QuarkPreferExclusiveConfigKey  = "quark_prefer_exclusive"

	QuarkAccountModeShared    = "shared"
	QuarkAccountModeExclusive = "exclusive"

	ErrCodeQuarkLoginRequired = "QUARK_LOGIN_REQUIRED"
)

var (
	ErrQuarkLoginRequired = errors.New("请先登录夸克账号")

	quarkCredentialConfigKeys = map[string]struct{}{
		quarkCookieConfigKey:         {},
		quarkTVRefreshTokenConfigKey: {},
		quarkTVDeviceIDConfigKey:     {},
		quarkTVQueryTokenConfigKey:   {},
	}

	quarkAccountShareModeEnsureOnce sync.Once

	// tests may override effective mode without a DB
	quarkAccountModeOverride func(userID uint) string
)

type QuarkAccountStatus struct {
	SystemMode           string `json:"systemMode"`
	PreferExclusive      bool   `json:"preferExclusive"`
	EffectiveMode        string `json:"effectiveMode"`
	CanPreferExclusive   bool   `json:"canPreferExclusive"`
	CanManageCredentials bool   `json:"canManageCredentials"`
	LoginRequired        bool   `json:"loginRequired"`
	CookieConfigured     bool   `json:"cookieConfigured"`
}

func isQuarkCredentialConfigKey(key string) bool {
	_, ok := quarkCredentialConfigKeys[strings.TrimSpace(key)]
	return ok
}

func normalizeQuarkAccountShareMode(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case QuarkAccountModeExclusive:
		return QuarkAccountModeExclusive
	default:
		return QuarkAccountModeShared
	}
}

func parsePreferExclusive(raw string) bool {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "1", "true", "yes", "y", "on":
		return true
	default:
		return false
	}
}

func formatPreferExclusive(value bool) string {
	if value {
		return "true"
	}
	return "false"
}

func ensureQuarkAccountShareModeConfig() {
	quarkAccountShareModeEnsureOnce.Do(func() {
		if global.DB == nil {
			return
		}
		_, err := configDao.GetByKey(QuarkAccountShareModeConfigKey)
		if err == nil {
			return
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			if global.Logger != nil {
				global.Logger.Warnf("读取 %s 失败: %v", QuarkAccountShareModeConfigKey, err)
			}
			return
		}
		err = configDao.AddOrUpdateConfig(&dto.ConfigUpdateDTO{
			Name:   "夸克账户共享状态",
			Key:    QuarkAccountShareModeConfigKey,
			Value:  QuarkAccountModeShared,
			IsLock: "1",
			Remark: "shared=共享夸克账号；exclusive=强制全员独享",
		})
		if err != nil && global.Logger != nil {
			global.Logger.Warnf("初始化 %s 失败: %v", QuarkAccountShareModeConfigKey, err)
		}
	})
}

func getQuarkAccountSystemMode() string {
	if global.DB == nil {
		return QuarkAccountModeShared
	}
	ensureQuarkAccountShareModeConfig()
	cfg, err := configDao.GetByKey(QuarkAccountShareModeConfigKey)
	if err != nil {
		return QuarkAccountModeShared
	}
	return normalizeQuarkAccountShareMode(cfg.Value)
}

func getQuarkPreferExclusive(userID uint) bool {
	if userID == 0 || global.DB == nil {
		return false
	}
	item, err := userConfigDao.GetByUserAndKey(userID, QuarkPreferExclusiveConfigKey)
	if err != nil {
		return false
	}
	return parsePreferExclusive(item.Value)
}

// resolveQuarkAccountMode 统一计算用户生效模式：
// 系统 exclusive → 全员独享；系统 shared → 看用户偏好。
func resolveQuarkAccountMode(userID uint) string {
	if quarkAccountModeOverride != nil {
		return normalizeQuarkAccountShareMode(quarkAccountModeOverride(userID))
	}
	if getQuarkAccountSystemMode() == QuarkAccountModeExclusive {
		return QuarkAccountModeExclusive
	}
	if getQuarkPreferExclusive(userID) {
		return QuarkAccountModeExclusive
	}
	return QuarkAccountModeShared
}

func isQuarkExclusiveMode(userID uint) bool {
	return resolveQuarkAccountMode(userID) == QuarkAccountModeExclusive
}

func canManageQuarkCredentials(loginUser model.LoginUser) bool {
	if loginUser.ID == 0 {
		return false
	}
	if isQuarkExclusiveMode(loginUser.ID) {
		return true
	}
	return loginUser.IsSuperAdmin()
}

func hasQuarkCookieConfigured(userID uint) bool {
	_, _, cookie, err := loadPrimaryQuarkCookieRecordForUser(userID)
	return err == nil && strings.TrimSpace(cookie) != ""
}

func buildQuarkAccountStatus(loginUser model.LoginUser) QuarkAccountStatus {
	systemMode := getQuarkAccountSystemMode()
	preferExclusive := getQuarkPreferExclusive(loginUser.ID)
	effectiveMode := resolveQuarkAccountMode(loginUser.ID)
	cookieConfigured := hasQuarkCookieConfigured(loginUser.ID)
	return QuarkAccountStatus{
		SystemMode:           systemMode,
		PreferExclusive:      preferExclusive,
		EffectiveMode:        effectiveMode,
		CanPreferExclusive:   systemMode == QuarkAccountModeShared,
		CanManageCredentials: canManageQuarkCredentials(loginUser),
		LoginRequired:        effectiveMode == QuarkAccountModeExclusive && !cookieConfigured,
		CookieConfigured:     cookieConfigured,
	}
}

func setQuarkAccountSystemMode(mode string) error {
	mode = normalizeQuarkAccountShareMode(mode)
	ensureQuarkAccountShareModeConfig()
	existing, err := configDao.GetByKey(QuarkAccountShareModeConfigKey)
	update := &dto.ConfigUpdateDTO{
		Name:   "夸克账户共享状态",
		Key:    QuarkAccountShareModeConfigKey,
		Value:  mode,
		IsLock: "1",
		Remark: "shared=共享夸克账号；exclusive=强制全员独享",
	}
	if err == nil {
		update.ID = existing.ID
		if strings.TrimSpace(existing.Name) != "" {
			update.Name = existing.Name
		}
		if strings.TrimSpace(existing.Remark) != "" {
			update.Remark = existing.Remark
		}
		if strings.TrimSpace(existing.IsLock) != "" {
			update.IsLock = existing.IsLock
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	return configDao.AddOrUpdateConfig(update)
}

func setQuarkPreferExclusive(userID uint, prefer bool) error {
	if userID == 0 {
		return errors.New("用户信息不存在")
	}
	if getQuarkAccountSystemMode() != QuarkAccountModeShared {
		return errors.New("管理员已强制独享，无法修改个人偏好")
	}
	_, err := userConfigDao.Upsert(userID, QuarkPreferExclusiveConfigKey, formatPreferExclusive(prefer), "用户是否优先使用独享夸克账号")
	return err
}

func IsQuarkLoginRequiredError(err error) bool {
	return err != nil && errors.Is(err, ErrQuarkLoginRequired)
}


func BuildQuarkAccountStatusExport(loginUser model.LoginUser) QuarkAccountStatus {
	return buildQuarkAccountStatus(loginUser)
}

func SetQuarkAccountSystemModeExport(mode string) error {
	return setQuarkAccountSystemMode(mode)
}

func SetQuarkPreferExclusiveExport(userID uint, prefer bool) error {
	return setQuarkPreferExclusive(userID, prefer)
}

func CanManageQuarkCredentialsExport(loginUser model.LoginUser) bool {
	return canManageQuarkCredentials(loginUser)
}

func GetQuarkCredentialConfigAsModel(userID uint, key string) (model.Config, bool, error) {
	key = strings.TrimSpace(key)
	if !isQuarkCredentialConfigKey(key) {
		return model.Config{}, false, errors.New("不是夸克凭证配置")
	}
	if isQuarkExclusiveMode(userID) {
		item, err := userConfigDao.GetByUserAndKey(userID, key)
		if err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return model.Config{}, false, nil
			}
			return model.Config{}, false, err
		}
		name, remark := quarkCredentialMeta(key)
		return model.Config{
			CommonModel: item.CommonModel,
			Name:        name,
			Key:         item.Key,
			Value:       item.Value,
			IsLock:      "1",
			Remark:      firstNonEmpty(item.Remark, remark),
		}, true, nil
	}
	cfg, err := configDao.GetByKey(key)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return model.Config{}, false, nil
		}
		return model.Config{}, false, err
	}
	return cfg, true, nil
}

func SaveQuarkCredentialConfig(userID uint, update *dto.ConfigUpdateDTO) error {
	if update == nil {
		return errors.New("配置不能为空")
	}
	key := strings.TrimSpace(update.Key)
	if !isQuarkCredentialConfigKey(key) {
		return errors.New("不是夸克凭证配置")
	}
	name, remark := quarkCredentialMeta(key)
	if strings.TrimSpace(update.Name) == "" {
		update.Name = name
	}
	if strings.TrimSpace(update.Remark) == "" {
		update.Remark = remark
	}
	if strings.TrimSpace(update.IsLock) == "" {
		update.IsLock = "1"
	}

	if isQuarkExclusiveMode(userID) {
		_, err := userConfigDao.Upsert(userID, key, update.Value, update.Remark)
		return err
	}
	if userID != 0 && !isQuarkExclusiveMode(userID) {
		// 共享模式下仅超管可写全局凭证；调用方已校验权限
	}
	existing, err := configDao.GetByKey(key)
	if err == nil {
		update.ID = existing.ID
		if strings.TrimSpace(update.Name) == "" {
			update.Name = existing.Name
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	return configDao.AddOrUpdateConfig(update)
}

func quarkCredentialMeta(key string) (string, string) {
	switch strings.TrimSpace(key) {
	case quarkCookieConfigKey:
		return "夸克cookies", "夸克网页登录 Cookie"
	case quarkTVRefreshTokenConfigKey:
		return "夸克TV刷新令牌", "夸克TV扫码登录 refresh_token"
	case quarkTVDeviceIDConfigKey:
		return "夸克TV设备ID", "夸克TV扫码登录 device_id"
	case quarkTVQueryTokenConfigKey:
		return "夸克TV扫码令牌", "夸克TV扫码登录 query_token"
	default:
		return key, ""
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
