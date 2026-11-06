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

	QuarkCredentialTargetAuto     = "auto"
	QuarkCredentialTargetShared   = "shared"
	QuarkCredentialTargetPersonal = "personal"

	ErrCodeQuarkLoginRequired             = "QUARK_LOGIN_REQUIRED"
	ErrCodeQuarkSharedCredentialInvalid   = "QUARK_SHARED_CREDENTIAL_UNAVAILABLE"
	ErrCodeQuarkPersonalCredentialBlocked = "QUARK_PERSONAL_CREDENTIAL_BLOCKED"
)

var (
	// ErrQuarkLoginRequired：独享模式下用户自己的夸克凭证缺失/失效，用户可自行重新登录修复。
	ErrQuarkLoginRequired = errors.New("请先登录夸克账号")
	// ErrQuarkSharedCredentialUnavailable：共享模式下全局夸克凭证缺失/失效，普通用户无法自行修复。
	ErrQuarkSharedCredentialUnavailable = errors.New("共享夸克账号未登录或已失效，请联系管理员")
	// ErrQuarkPersonalCredentialDisabled：共享模式下不存在个人凭证的读写语义，显式要求个人凭证视为非法请求。
	ErrQuarkPersonalCredentialDisabled = errors.New("当前为共享夸克账号模式，不维护个人凭证")

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
	// SuggestedCredentialTarget 由后端统一下发，前端不要再自行推断凭证落库目标。
	SuggestedCredentialTarget string `json:"suggestedCredentialTarget"`
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

func normalizeQuarkCredentialTarget(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case QuarkCredentialTargetShared:
		return QuarkCredentialTargetShared
	case QuarkCredentialTargetPersonal:
		return QuarkCredentialTargetPersonal
	default:
		return QuarkCredentialTargetAuto
	}
}

// resolveQuarkCredentialUsePersonal 是凭证落库位置的唯一真源，
// 读（loadPrimaryQuarkCookieRecordForUser / getOptionalConfigByKeyForUser）
// 与写（SaveQuarkCredentialConfig / DeleteQuarkCredentialConfig）都必须走这里，
// 否则会出现「写到 A 处、运行时读 B 处」的静默失效。
//
// shared → 全局 sys_config；personal → 用户 sys_user_config；
// auto → 跟随生效模式（独享走个人，共享走全局）。
func resolveQuarkCredentialUsePersonal(userID uint, target string) (bool, error) {
	switch normalizeQuarkCredentialTarget(target) {
	case QuarkCredentialTargetShared:
		return false, nil
	case QuarkCredentialTargetPersonal:
		if userID == 0 {
			return false, errors.New("用户信息不存在")
		}
		// 共享模式下运行时永远读全局凭证，个人凭证不会被任何链路使用，
		// 因此必须显式拒绝，避免写入「死数据」并让配置页误显示已配置。
		if !isQuarkExclusiveMode(userID) {
			return false, ErrQuarkPersonalCredentialDisabled
		}
		return true, nil
	default:
		return quarkCredentialUsePersonal(userID), nil
	}
}

// quarkCredentialUsePersonal 返回 auto 语义下的落库位置，即「运行时实际读取的位置」。
func quarkCredentialUsePersonal(userID uint) bool {
	return userID != 0 && isQuarkExclusiveMode(userID)
}

// suggestedQuarkCredentialTarget 下发前端应使用的凭证目标，避免前端自行猜测。
func suggestedQuarkCredentialTarget(userID uint) string {
	if quarkCredentialUsePersonal(userID) {
		return QuarkCredentialTargetPersonal
	}
	return QuarkCredentialTargetShared
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
		SystemMode:                systemMode,
		PreferExclusive:           preferExclusive,
		EffectiveMode:             effectiveMode,
		CanPreferExclusive:        systemMode == QuarkAccountModeShared,
		CanManageCredentials:      canManageQuarkCredentials(loginUser),
		LoginRequired:             effectiveMode == QuarkAccountModeExclusive && !cookieConfigured,
		CookieConfigured:          cookieConfigured,
		SuggestedCredentialTarget: suggestedQuarkCredentialTarget(loginUser.ID),
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

func IsQuarkSharedCredentialUnavailableError(err error) bool {
	return err != nil && errors.Is(err, ErrQuarkSharedCredentialUnavailable)
}

func IsQuarkPersonalCredentialDisabledError(err error) bool {
	return err != nil && errors.Is(err, ErrQuarkPersonalCredentialDisabled)
}

// QuarkErrorCode 把夸克凭证类错误映射成前端可判别的业务码。
// 前端不再依赖错误文案做分支，避免后端改文案就悄悄失效。
func QuarkErrorCode(err error) string {
	switch {
	case IsQuarkLoginRequiredError(err):
		return ErrCodeQuarkLoginRequired
	case IsQuarkSharedCredentialUnavailableError(err):
		return ErrCodeQuarkSharedCredentialInvalid
	case IsQuarkPersonalCredentialDisabledError(err):
		return ErrCodeQuarkPersonalCredentialBlocked
	default:
		return ""
	}
}

// QuarkErrorMessage 返回面向终端用户的提示文案。
func QuarkErrorMessage(err error) string {
	switch {
	case IsQuarkLoginRequiredError(err):
		return ErrQuarkLoginRequired.Error()
	case IsQuarkSharedCredentialUnavailableError(err):
		return ErrQuarkSharedCredentialUnavailable.Error()
	case IsQuarkPersonalCredentialDisabledError(err):
		return ErrQuarkPersonalCredentialDisabled.Error()
	default:
		return err.Error()
	}
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

func NormalizeQuarkCredentialTargetExport(raw string) string {
	return normalizeQuarkCredentialTarget(raw)
}

func ResolveQuarkCredentialUsePersonalExport(userID uint, target string) (bool, error) {
	return resolveQuarkCredentialUsePersonal(userID, target)
}

func IsQuarkExclusiveModeExport(userID uint) bool {
	return isQuarkExclusiveMode(userID)
}

// CanAccessQuarkCredentialTargetExport 判断用户能否读写指定目标的夸克凭证。
// shared → 仅超管；personal → 必须处于独享模式且具备凭证管理权限。
func CanAccessQuarkCredentialTargetExport(loginUser model.LoginUser, target string) bool {
	if loginUser.ID == 0 {
		return false
	}
	switch normalizeQuarkCredentialTarget(target) {
	case QuarkCredentialTargetShared:
		return loginUser.IsSuperAdmin()
	case QuarkCredentialTargetPersonal:
		return canManageQuarkCredentials(loginUser) && isQuarkExclusiveMode(loginUser.ID)
	default:
		return canManageQuarkCredentials(loginUser)
	}
}

func GetQuarkCredentialConfigAsModel(userID uint, key string, target string) (model.Config, bool, error) {
	key = strings.TrimSpace(key)
	if !isQuarkCredentialConfigKey(key) {
		return model.Config{}, false, errors.New("不是夸克凭证配置")
	}
	usePersonal, err := resolveQuarkCredentialUsePersonal(userID, target)
	if err != nil {
		return model.Config{}, false, err
	}
	if usePersonal {
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

func SaveQuarkCredentialConfig(userID uint, update *dto.ConfigUpdateDTO, target string) error {
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

	usePersonal, err := resolveQuarkCredentialUsePersonal(userID, target)
	if err != nil {
		return err
	}
	if usePersonal {
		update.ID = 0 // 避免把 user_config 的 ID 误当成全局 sys_config 主键
		if strings.TrimSpace(update.Value) == "" {
			return userConfigDao.DeleteByUserAndKey(userID, key)
		}
		_, err := userConfigDao.Upsert(userID, key, update.Value, update.Remark)
		return err
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

func DeleteQuarkCredentialConfig(userID uint, key string, target string) error {
	key = strings.TrimSpace(key)
	if !isQuarkCredentialConfigKey(key) {
		return errors.New("不是夸克凭证配置")
	}
	usePersonal, err := resolveQuarkCredentialUsePersonal(userID, target)
	if err != nil {
		return err
	}
	if usePersonal {
		return userConfigDao.DeleteByUserAndKey(userID, key)
	}
	existing, err := configDao.GetByKey(key)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil
		}
		return err
	}
	return configDao.DeleteConfig(existing.ID)
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

func SetQuarkAccountModeOverrideForTest(fn func(userID uint) string) {
	quarkAccountModeOverride = fn
}

func ClearQuarkAccountModeOverrideForTest() {
	quarkAccountModeOverride = nil
}
