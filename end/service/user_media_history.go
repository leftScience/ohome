package service

import (
	"errors"
	"fmt"
	"ohome/model"
	"ohome/service/dto"
	"strings"
	"time"

	"gorm.io/gorm"
)

type UserMediaHistoryService struct {
	BaseService
}

func (s *UserMediaHistoryService) Create(historyDTO *dto.UserMediaHistoryCreateDTO) (model.UserMediaHistory, error) {
	var history model.UserMediaHistory

	lastPlayedAt := time.Now()
	if strings.TrimSpace(historyDTO.LastPlayedAt) != "" {
		parsed, err := parseHistoryTime(historyDTO.LastPlayedAt)
		if err != nil {
			return history, err
		}
		lastPlayedAt = parsed
	}

	historyDTO.FillModel(&history, lastPlayedAt)
	history.PrepareForSave()

	record, err := userMediaHistoryDao.UpsertByUserAppFolder(&history)
	if err != nil {
		return record, err
	}
	record.NormalizePlaybackFields()
	return record, nil
}

func (s *UserMediaHistoryService) GetByID(idDTO *dto.CommonIDDTO) (model.UserMediaHistory, error) {
	if idDTO.ID == 0 {
		return model.UserMediaHistory{}, errors.New("记录ID不能为空")
	}

	record, err := userMediaHistoryDao.GetByID(idDTO.ID)
	if err != nil {
		return record, err
	}
	record.NormalizePlaybackFields()
	return record, nil
}

func (s *UserMediaHistoryService) GetList(listDTO *dto.UserMediaHistoryListDTO) ([]model.UserMediaHistory, int64, error) {
	records, total, err := userMediaHistoryDao.List(listDTO)
	if err != nil {
		return records, total, err
	}
	for i := range records {
		records[i].NormalizePlaybackFields()
	}
	return records, total, nil
}

func (s *UserMediaHistoryService) GetRecent(recentDTO *dto.UserMediaHistoryRecentDTO) (model.UserMediaHistory, error) {
	if recentDTO.UserID == 0 {
		return model.UserMediaHistory{}, errors.New("用户ID不能为空")
	}
	record, err := userMediaHistoryDao.GetMostRecent(recentDTO)
	if err != nil {
		return record, err
	}
	record.NormalizePlaybackFields()
	return record, nil
}

func (s *UserMediaHistoryService) GetByFolder(folderDTO *dto.UserMediaHistoryFolderDTO) (*model.UserMediaHistory, error) {
	if folderDTO.UserID == 0 {
		return nil, errors.New("用户ID不能为空")
	}
	if strings.TrimSpace(folderDTO.ApplicationType) == "" {
		return nil, errors.New("应用类型不能为空")
	}
	if strings.TrimSpace(folderDTO.FolderPath) == "" {
		return nil, errors.New("文件夹路径不能为空")
	}

	record, err := userMediaHistoryDao.GetByUserAppFolder(folderDTO)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	record.NormalizePlaybackFields()
	return &record, nil
}

func (s *UserMediaHistoryService) Update(updateDTO *dto.UserMediaHistoryUpdateDTO) error {
	if updateDTO.ID == 0 {
		return errors.New("记录ID不能为空")
	}

	history, err := userMediaHistoryDao.GetByID(updateDTO.ID)
	if err != nil {
		return err
	}

	var parsed *time.Time
	if updateDTO.LastPlayedAt != nil {
		if strings.TrimSpace(*updateDTO.LastPlayedAt) == "" {
			return errors.New("最后播放时间不能为空")
		}

		lastPlayed, err := parseHistoryTime(*updateDTO.LastPlayedAt)
		if err != nil {
			return err
		}
		parsed = &lastPlayed
	}

	updateDTO.ApplyToModel(&history, parsed)
	history.PrepareForSave()

	return userMediaHistoryDao.Save(&history)
}

func (s *UserMediaHistoryService) Delete(idDTO *dto.CommonIDDTO) error {
	if idDTO.ID == 0 {
		return errors.New("记录ID不能为空")
	}
	return userMediaHistoryDao.Delete(idDTO.ID)
}

func parseHistoryTime(value string) (time.Time, error) {
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		time.DateTime,
		"2006-01-02 15:04:05",
		"2006-01-02T15:04:05.999999",
	}

	for _, layout := range layouts {
		if parsed, err := time.ParseInLocation(layout, value, time.Local); err == nil {
			return parsed, nil
		}
	}

	return time.Time{}, fmt.Errorf("无法解析时间[%s]，请使用 RFC3339 或 2006-01-02 15:04:05 格式", value)
}
