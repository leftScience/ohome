package dao

import (
	"ohome/global"
	"ohome/model"
	"ohome/service/dto"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type UserMediaHistoryDao struct {
	BaseDao
}

func (d *UserMediaHistoryDao) GetByID(id uint) (model.UserMediaHistory, error) {
	var history model.UserMediaHistory
	err := global.DB.First(&history, id).Error
	return history, err
}

func (d *UserMediaHistoryDao) List(listDTO *dto.UserMediaHistoryListDTO) ([]model.UserMediaHistory, int64, error) {
	var histories []model.UserMediaHistory
	var total int64

	query := global.DB.Model(&model.UserMediaHistory{}).
		Scopes(Paginate(listDTO.Paginate)).
		Order("last_played_at desc")

	if listDTO.UserID != 0 {
		query = query.Where("user_id = ?", listDTO.UserID)
	}
	if listDTO.ApplicationType != "" {
		query = query.Where("application_type = ?", listDTO.ApplicationType)
	}
	if listDTO.FolderPath != "" {
		query = query.Where("folder_path LIKE ?", "%"+listDTO.FolderPath+"%")
	}
	if listDTO.ItemTitle != "" {
		query = query.Where("item_title LIKE ?", "%"+listDTO.ItemTitle+"%")
	}

	err := query.
		Find(&histories).
		Offset(-1).Limit(-1).
		Count(&total).Error

	return histories, total, err
}

func (d *UserMediaHistoryDao) Save(history *model.UserMediaHistory) error {
	return global.DB.Save(history).Error
}

func (d *UserMediaHistoryDao) Delete(id uint) error {
	return global.DB.Delete(&model.UserMediaHistory{}, id).Error
}

func (d *UserMediaHistoryDao) DeleteByUserIDWithDB(db *gorm.DB, userID uint) error {
	if userID == 0 {
		return nil
	}
	return db.Where("user_id = ?", userID).Delete(&model.UserMediaHistory{}).Error
}

func (d *UserMediaHistoryDao) UpsertByUserAppFolder(history *model.UserMediaHistory) (model.UserMediaHistory, error) {
	history.PrepareForSave()

	err := global.DB.Clauses(clause.OnConflict{
		Columns: []clause.Column{
			{Name: "unique_key"},
		},
		DoUpdates: clause.Assignments(map[string]interface{}{
			"item_title":     history.ItemTitle,
			"item_path":      history.ItemPath,
			"position_ms":    history.PositionMs,
			"duration_ms":    history.DurationMs,
			"cover_url":      history.CoverURL,
			"extra":          history.Extra,
			"last_played_at": history.LastPlayedAt,
			"updated_at":     time.Now(),
			"deleted_at":     nil,
		}),
	}).Create(history).Error
	if err != nil {
		return *history, err
	}

	err = global.DB.Where("unique_key = ?", history.UniqueKey).First(history).Error
	return *history, err
}

func (d *UserMediaHistoryDao) GetMostRecent(recentDTO *dto.UserMediaHistoryRecentDTO) (model.UserMediaHistory, error) {
	var history model.UserMediaHistory
	query := global.DB.Where("user_id = ?", recentDTO.UserID)
	if strings.TrimSpace(recentDTO.ApplicationType) != "" {
		query = query.Where("application_type = ?", recentDTO.ApplicationType)
	}
	err := query.Order("last_played_at desc").Limit(1).First(&history).Error
	return history, err
}

func (d *UserMediaHistoryDao) GetByUserAppFolder(folderDTO *dto.UserMediaHistoryFolderDTO) (model.UserMediaHistory, error) {
	var history model.UserMediaHistory

	folderPath := normalizeFolderPathForLookup(folderDTO.FolderPath)
	if folderDTO.UserID == 0 || strings.TrimSpace(folderDTO.ApplicationType) == "" || folderPath == "" {
		return history, gorm.ErrRecordNotFound
	}

	err := global.DB.
		Where("user_id = ?", folderDTO.UserID).
		Where("application_type = ?", strings.TrimSpace(folderDTO.ApplicationType)).
		Where("folder_path = ?", folderPath).
		Order("last_played_at desc").
		First(&history).Error
	return history, err
}

func normalizeFolderPathForLookup(value string) string {
	normalized := strings.TrimSpace(strings.ReplaceAll(value, "\\", "/"))
	if normalized == "" {
		return ""
	}

	rawParts := strings.Split(normalized, "/")
	parts := make([]string, 0, len(rawParts))
	for _, part := range rawParts {
		trimmed := strings.TrimSpace(part)
		if trimmed == "" {
			continue
		}
		parts = append(parts, trimmed)
	}
	if len(parts) == 0 {
		if strings.HasPrefix(normalized, "/") {
			return "/"
		}
		return ""
	}
	return "/" + strings.Join(parts, "/")
}
