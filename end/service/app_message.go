package service

import (
	"fmt"
	"ohome/global"
	"ohome/model"
	"ohome/service/dto"
	"sort"
	"strings"
	"time"
)

type AppMessageService struct {
	BaseService
}

func (s *AppMessageService) GetList(listDTO *dto.AppMessageListDTO, ownerUserID uint) ([]model.AppMessage, int64, error) {
	query := global.DB.Model(&model.AppMessage{}).Where("owner_user_id = ?", ownerUserID)
	if source := strings.TrimSpace(strings.ToLower(listDTO.Source)); source != "" {
		query = query.Where("source = ?", source)
	}
	if listDTO.ReadOnly != nil {
		query = query.Where("read = ?", *listDTO.ReadOnly)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	result := make([]model.AppMessage, 0, listDTO.GetLimit())
	err := query.
		Order("read ASC").
		Order("trigger_date DESC").
		Order("created_at DESC").
		Offset((listDTO.GetPage() - 1) * listDTO.GetLimit()).
		Limit(listDTO.GetLimit()).
		Find(&result).Error
	return result, total, err
}

func (s *AppMessageService) CountUnread(ownerUserID uint, source string) (int64, error) {
	query := global.DB.Model(&model.AppMessage{}).
		Where("owner_user_id = ? AND read = ?", ownerUserID, false)
	if source = strings.TrimSpace(strings.ToLower(source)); source != "" {
		query = query.Where("source = ?", source)
	}

	var total int64
	err := query.Count(&total).Error
	return total, err
}

func (s *AppMessageService) MarkRead(id, ownerUserID uint) error {
	now := time.Now()
	tx := global.DB.Model(&model.AppMessage{}).
		Where("id = ? AND owner_user_id = ?", id, ownerUserID).
		Where("read = ?", false).
		Updates(map[string]any{
			"read":    true,
			"read_at": &now,
		})
	if tx.Error != nil {
		return tx.Error
	}
	if tx.RowsAffected > 0 {
		NotifyAppMessageOwners([]uint{ownerUserID}, "read", id)
	}
	return nil
}

func (s *AppMessageService) MarkAllRead(ownerUserID uint) error {
	now := time.Now()
	tx := global.DB.Model(&model.AppMessage{}).
		Where("owner_user_id = ? AND read = ?", ownerUserID, false).
		Updates(map[string]any{
			"read":    true,
			"read_at": &now,
		})
	if tx.Error != nil {
		return tx.Error
	}
	if tx.RowsAffected > 0 {
		NotifyAppMessageOwners([]uint{ownerUserID}, "read_all")
	}
	return nil
}

func (s *AppMessageService) Delete(id, ownerUserID uint) error {
	tx := global.DB.
		Where("id = ? AND owner_user_id = ?", id, ownerUserID).
		Delete(&model.AppMessage{})
	if tx.Error != nil {
		return tx.Error
	}
	if tx.RowsAffected > 0 {
		NotifyAppMessageOwners([]uint{ownerUserID}, "deleted", id)
	}
	return nil
}

func (s *AppMessageService) SaveMessages(messages []model.AppMessage) error {
	createdMessageIDs := make(map[uint][]uint, len(messages))
	for _, message := range messages {
		if strings.TrimSpace(message.UniqueKey) == "" {
			continue
		}
		message.Read = false
		message.ReadAt = nil
		tx := global.DB.Where("unique_key = ?", message.UniqueKey).FirstOrCreate(&message)
		if tx.Error != nil {
			return tx.Error
		}
		if tx.RowsAffected > 0 && message.OwnerUserID != 0 && message.ID != 0 {
			createdMessageIDs[message.OwnerUserID] = append(createdMessageIDs[message.OwnerUserID], message.ID)
		}
	}

	for ownerUserID, messageIDs := range createdMessageIDs {
		NotifyAppMessageOwners([]uint{ownerUserID}, "created", messageIDs...)
	}
	return nil
}

func (s *AppMessageService) SaveQuarkTransferResult(task model.QuarkTransferTask) error {
	if task.ID == 0 {
		return nil
	}

	recipients, err := s.resolveQuarkRecipients(task.OwnerUserID)
	if err != nil {
		return err
	}
	if len(recipients) == 0 {
		return nil
	}

	triggerAt := time.Now()
	if task.FinishedAt != nil {
		triggerAt = *task.FinishedAt
	}

	messages := make([]model.AppMessage, 0, len(recipients))
	for _, recipientID := range recipients {
		sourceKey := fmt.Sprintf("quark_transfer:%d:%s:%d", task.ID, task.Status, recipientID)
		messages = append(messages, model.AppMessage{
			OwnerUserID: recipientID,
			Source:      model.AppMessageSourceQuark,
			SourceKey:   sourceKey,
			MessageType: quarkTransferAppMessageType(task.Status),
			BizType:     model.AppMessageBizTypeQuarkTransferTask,
			BizID:       task.ID,
			UniqueKey:   model.BuildAppMessageUniqueKey(model.AppMessageSourceQuark, sourceKey),
			Title:       s.buildQuarkTransferMessageTitle(task),
			Summary:     s.buildQuarkTransferMessageSummary(task),
			TriggerDate: triggerAt,
		})
	}

	return s.SaveMessages(messages)
}

func (s *AppMessageService) ListRecipientUserIDs() ([]uint, error) {
	type row struct {
		ID uint `gorm:"column:id"`
	}
	rows := make([]row, 0, 8)
	if err := global.DB.Model(&model.User{}).Select("id").Find(&rows).Error; err != nil {
		return nil, err
	}
	result := make([]uint, 0, len(rows))
	for _, row := range rows {
		if row.ID != 0 {
			result = append(result, row.ID)
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i] < result[j] })
	return result, nil
}

func (s *AppMessageService) resolveQuarkRecipients(ownerUserID uint) ([]uint, error) {
	if ownerUserID != 0 {
		return []uint{ownerUserID}, nil
	}
	return s.ListRecipientUserIDs()
}

func quarkTransferAppMessageType(status string) string {
	switch strings.TrimSpace(strings.ToLower(status)) {
	case model.QuarkTransferTaskStatusFailed:
		return model.AppMessageTypeQuarkTransferFail
	default:
		return model.AppMessageTypeQuarkTransferDone
	}
}

func (s *AppMessageService) buildQuarkTransferMessageTitle(task model.QuarkTransferTask) string {
	name := strings.TrimSpace(task.DisplayName)
	if name == "" {
		name = "未命名资源"
	}

	prefix := "夸克转存"
	if task.SourceType == model.QuarkTransferTaskSourceSyncManual ||
		task.SourceType == model.QuarkTransferTaskSourceSyncSchedule {
		prefix = "夸克同步"
	}

	if task.Status == model.QuarkTransferTaskStatusFailed {
		return fmt.Sprintf("%s失败：%s", prefix, name)
	}
	return fmt.Sprintf("%s完成：%s", prefix, name)
}

func (s *AppMessageService) buildQuarkTransferMessageSummary(task model.QuarkTransferTask) string {
	parts := make([]string, 0, 3)
	if path := strings.TrimSpace(task.SavePath); path != "" {
		parts = append(parts, "保存路径："+ensureAppMessageLeadingSlash(path))
	}
	if task.Status == model.QuarkTransferTaskStatusSuccess {
		parts = append(parts, fmt.Sprintf("新增资源：%d 项", task.SavedCount))
	}
	if message := strings.TrimSpace(task.ResultMessage); message != "" {
		parts = append(parts, message)
	}
	return strings.Join(parts, "；")
}

func ensureAppMessageLeadingSlash(value string) string {
	text := strings.TrimSpace(strings.ReplaceAll(value, "\\", "/"))
	if text == "" {
		return ""
	}
	if strings.HasPrefix(text, "/") {
		return text
	}
	return "/" + text
}

func (s *AppMessageService) SendSystemMessageToAll(title, content string, senderID uint) error {
	recipients, err := s.ListRecipientUserIDs()
	if err != nil {
		return err
	}
	if len(recipients) == 0 {
		return nil
	}

	now := time.Now()
	messages := make([]model.AppMessage, 0, len(recipients))
	for _, recipientID := range recipients {
		sourceKey := fmt.Sprintf("system_broadcast:%d:%d", now.Unix(), recipientID)
		messages = append(messages, model.AppMessage{
			OwnerUserID: recipientID,
			CreatedBy:   senderID,
			Source:      model.AppMessageSourceSystem,
			SourceKey:   sourceKey,
			MessageType: model.AppMessageTypeSystemBroadcast,
			Title:       title,
			Summary:     content,
			UniqueKey:   model.BuildAppMessageUniqueKey(model.AppMessageSourceSystem, sourceKey),
			TriggerDate: now,
		})
	}

	return s.SaveMessages(messages)
}
