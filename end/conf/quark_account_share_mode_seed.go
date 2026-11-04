package conf

import (
	"errors"
	"ohome/model"
	"strings"

	"gorm.io/gorm"
)

const quarkAccountShareModeConfigKey = "quark_account_share_mode"

func ensureQuarkAccountShareModeSeed(db *gorm.DB) error {
	if db == nil {
		return nil
	}
	var existing model.Config
	err := db.Where("`key` = ?", quarkAccountShareModeConfigKey).First(&existing).Error
	if err == nil {
		return nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	return db.Create(&model.Config{
		Name:   "夸克账户共享状态",
		Key:    quarkAccountShareModeConfigKey,
		Value:  "shared",
		IsLock: "1",
		Remark: "shared=共享夸克账号；exclusive=强制全员独享",
	}).Error
}

func normalizeQuarkAccountShareModeValue(raw string) string {
	if strings.EqualFold(strings.TrimSpace(raw), "exclusive") {
		return "exclusive"
	}
	return "shared"
}
