package conf

import (
	"strings"
	"time"

	"ohome/model"

	"gorm.io/gorm"
)

const (
	quarkMusicApplication = "music"
	quarkReadApplication  = "read"
	quarkNovelApplication = "xiaoshuo"
	quarkReadRootPath     = "WP/READ"
	quarkMusicRemark      = "播客"
	quarkReadRemark       = "阅读"
)

func migrateQuarkApplications(db *gorm.DB) error {
	return db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Unscoped().
			Where("application = ?", quarkNovelApplication).
			Delete(&model.QuarkConfig{}).Error; err != nil {
			return err
		}

		if err := tx.Model(&model.QuarkConfig{}).
			Where("application = ?", quarkMusicApplication).
			Update("remark", quarkMusicRemark).Error; err != nil {
			return err
		}

		var existing model.QuarkConfig
		err := tx.Where("application = ?", quarkReadApplication).First(&existing).Error
		if err == nil {
			updates := map[string]any{}
			if strings.TrimSpace(existing.Remark) == "" {
				updates["remark"] = quarkReadRemark
			}
			if strings.TrimSpace(existing.RootPath) == "" {
				updates["root_path"] = quarkReadRootPath
			}
			if len(updates) > 0 {
				if err := tx.Model(&model.QuarkConfig{}).
					Where("application = ?", quarkReadApplication).
					Updates(updates).Error; err != nil {
					return err
				}
			}
			return nil
		}
		if err != gorm.ErrRecordNotFound {
			return err
		}

		now := time.Now()
		return tx.Create(&model.QuarkConfig{
			Application: quarkReadApplication,
			RootPath:    quarkReadRootPath,
			Remark:      quarkReadRemark,
			CreatedAt:   now,
			UpdatedAt:   now,
		}).Error
	})
}
