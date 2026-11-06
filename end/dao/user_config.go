package dao

import (
	"errors"
	"ohome/global"
	"ohome/model"
	"strings"

	"gorm.io/gorm"
)

type UserConfigDao struct {
	BaseDao
}

func (m *UserConfigDao) GetByUserAndKey(userID uint, key string) (model.UserConfig, error) {
	var item model.UserConfig
	err := global.DB.Where("user_id = ? AND `key` = ?", userID, strings.TrimSpace(key)).First(&item).Error
	return item, err
}

func (m *UserConfigDao) GetByUserAndKeys(userID uint, keys []string) ([]model.UserConfig, error) {
	normalized := make([]string, 0, len(keys))
	for _, key := range keys {
		key = strings.TrimSpace(key)
		if key != "" {
			normalized = append(normalized, key)
		}
	}
	if userID == 0 || len(normalized) == 0 {
		return []model.UserConfig{}, nil
	}
	var items []model.UserConfig
	err := global.DB.Where("user_id = ? AND `key` IN ?", userID, normalized).Find(&items).Error
	return items, err
}

func (m *UserConfigDao) Upsert(userID uint, key, value, remark string) (model.UserConfig, error) {
	key = strings.TrimSpace(key)
	if userID == 0 || key == "" {
		return model.UserConfig{}, errors.New("user config key invalid")
	}
	var existing model.UserConfig
	err := global.DB.Unscoped().
		Where("user_id = ? AND `key` = ?", userID, key).
		First(&existing).Error
	if err != nil {
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return model.UserConfig{}, err
		}
		item := model.UserConfig{
			UserID: userID,
			Key:    key,
			Value:  value,
			Remark: strings.TrimSpace(remark),
		}
		if err := global.DB.Create(&item).Error; err != nil {
			return model.UserConfig{}, err
		}
		return item, nil
	}

	existing.Value = value
	if strings.TrimSpace(remark) != "" {
		existing.Remark = strings.TrimSpace(remark)
	}
	if err := global.DB.Unscoped().Model(&existing).Updates(map[string]interface{}{
		"value":      existing.Value,
		"remark":     existing.Remark,
		"deleted_at": nil,
	}).Error; err != nil {
		return model.UserConfig{}, err
	}
	existing.DeletedAt = gorm.DeletedAt{}
	return existing, nil
}

func (m *UserConfigDao) DeleteByUserAndKey(userID uint, key string) error {
	return global.DB.Unscoped().
		Where("user_id = ? AND `key` = ?", userID, strings.TrimSpace(key)).
		Delete(&model.UserConfig{}).Error
}

func (m *UserConfigDao) DeleteByUserIDWithDB(db *gorm.DB, userID uint) error {
	if db == nil {
		db = global.DB
	}
	return db.Where("user_id = ?", userID).Delete(&model.UserConfig{}).Error
}
