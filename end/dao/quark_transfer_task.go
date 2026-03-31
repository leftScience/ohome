package dao

import (
	"ohome/global"
	"ohome/model"
	"ohome/service/dto"
	"time"

	"gorm.io/gorm"
)

type QuarkTransferTaskDao struct {
	BaseDao
}

func (d *QuarkTransferTaskDao) GetByID(id uint, ownerUserID uint) (model.QuarkTransferTask, error) {
	var task model.QuarkTransferTask
	err := global.DB.Where("owner_user_id = ?", ownerUserID).First(&task, id).Error
	return task, err
}

func (d *QuarkTransferTaskDao) Delete(id uint, ownerUserID uint) error {
	return global.DB.Where("owner_user_id = ?", ownerUserID).Delete(&model.QuarkTransferTask{}, id).Error
}

func (d *QuarkTransferTaskDao) DeleteByOwnerUserIDWithDB(db *gorm.DB, ownerUserID uint) error {
	if ownerUserID == 0 {
		return nil
	}
	return db.Where("owner_user_id = ?", ownerUserID).Delete(&model.QuarkTransferTask{}).Error
}

func (d *QuarkTransferTaskDao) Create(task *model.QuarkTransferTask, sourceTaskID *uint, startedAt time.Time) error {
	return global.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(task).Error; err != nil {
			return err
		}
		if sourceTaskID == nil || *sourceTaskID == 0 {
			return nil
		}
		return tx.Model(&model.QuarkAutoSaveTask{}).
			Where("id = ?", *sourceTaskID).
			Updates(map[string]any{
				"last_run_at": startedAt,
			}).Error
	})
}

func (d *QuarkTransferTaskDao) MarkProcessing(id uint, startedAt time.Time) (bool, error) {
	tx := global.DB.Model(&model.QuarkTransferTask{}).
		Where("id = ? AND status = ?", id, model.QuarkTransferTaskStatusQueued).
		Updates(map[string]any{
			"status":         model.QuarkTransferTaskStatusProcessing,
			"started_at":     startedAt,
			"finished_at":    nil,
			"result_message": "",
			"saved_count":    0,
		})
	return tx.RowsAffected > 0, tx.Error
}

func (d *QuarkTransferTaskDao) UpdateTaskResult(id uint, updates map[string]any) error {
	return global.DB.Model(&model.QuarkTransferTask{}).
		Where("id = ?", id).
		Updates(updates).Error
}

func (d *QuarkTransferTaskDao) GetList(listDTO *dto.QuarkTransferTaskListDTO, ownerUserID uint) ([]model.QuarkTransferTask, int64, error) {
	records := make([]model.QuarkTransferTask, 0)
	var total int64

	filtered := global.DB.Model(&model.QuarkTransferTask{}).Where("owner_user_id = ?", ownerUserID)
	if listDTO.Status != "" {
		filtered = filtered.Where("status = ?", listDTO.Status)
	}
	if listDTO.SourceType != "" {
		filtered = filtered.Where("source_type = ?", listDTO.SourceType)
	}

	if err := filtered.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	if err := filtered.
		Order("id desc").
		Scopes(Paginate(listDTO.Paginate)).
		Find(&records).Error; err != nil {
		return nil, 0, err
	}

	return records, total, nil
}

func (d *QuarkTransferTaskDao) RecoverInterruptedTasks(now time.Time) (int64, error) {
	result := global.DB.Model(&model.QuarkTransferTask{}).
		Where("status IN ?", []string{
			model.QuarkTransferTaskStatusQueued,
			model.QuarkTransferTaskStatusProcessing,
		}).
		Updates(map[string]any{
			"status":         model.QuarkTransferTaskStatusFailed,
			"result_message": "服务重启导致任务中断",
			"saved_count":    0,
			"finished_at":    now,
		})
	return result.RowsAffected, result.Error
}
