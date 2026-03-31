package service

import (
	"context"
	"errors"
	"fmt"
	"mime/multipart"
	"ohome/global"
	"ohome/model"
	"ohome/service/dto"
	"path"
	"strings"
	"time"

	"gorm.io/gorm"
)

type DropsItemService struct {
	BaseService
}

func (s *DropsItemService) GetOverview(loginUser model.LoginUser, loc *time.Location) (DropsOverview, error) {
	items, _, err := s.GetList(&dto.DropsItemListDTO{
		Paginate: dto.Paginate{Page: 1, Limit: 10000},
	}, loginUser, true)
	if err != nil {
		return DropsOverview{}, err
	}
	events, _, err := (&DropsEventService{}).GetList(&dto.DropsEventListDTO{
		Paginate: dto.Paginate{Page: 1, Limit: 10000},
	}, loginUser, true, loc)
	if err != nil {
		return DropsOverview{}, err
	}

	start := dropsStartOfDay(time.Now().In(loc), loc)
	endSoon := start.AddDate(0, 0, 7)

	var itemSoonCount int64
	if err := s.baseVisibleQuery(loginUser).
		Model(&model.DropsItem{}).
		Where("expire_at IS NOT NULL").
		Where("enabled = ?", true).
		Where("date(expire_at) >= date(?) AND date(expire_at) <= date(?)", start, endSoon).
		Count(&itemSoonCount).Error; err != nil {
		return DropsOverview{}, err
	}

	messagesUnread, err := (&AppMessageService{}).CountUnread(loginUser.ID, "")
	if err != nil {
		return DropsOverview{}, err
	}

	todayTodoCount := 0
	for _, item := range items {
		if item.ExpireAt != nil && dropsDaysUntil(start, *item.ExpireAt, loc) == 0 {
			todayTodoCount++
		}
	}
	monthEventCount := 0
	for _, event := range events {
		if event.NextOccurAt == nil {
			continue
		}
		if event.NextOccurAt.Year() == start.Year() && event.NextOccurAt.Month() == start.Month() {
			monthEventCount++
		}
		if dropsDaysUntil(start, *event.NextOccurAt, loc) == 0 {
			todayTodoCount++
		}
	}

	return DropsOverview{
		TodayTodoCount:     todayTodoCount,
		ExpiringSoonCount:  int(itemSoonCount),
		MonthEventCount:    monthEventCount,
		UnreadMessageCount: int(messagesUnread),
		RecentItems:        limitDropsItems(items, 5),
		RecentEvents:       limitDropsEvents(events, 5),
	}, nil
}

func limitDropsItems(items []model.DropsItem, limit int) []model.DropsItem {
	if len(items) <= limit {
		return items
	}
	return items[:limit]
}

func limitDropsEvents(events []model.DropsEvent, limit int) []model.DropsEvent {
	if len(events) <= limit {
		return events
	}
	return events[:limit]
}

func (s *DropsItemService) GetList(listDTO *dto.DropsItemListDTO, loginUser model.LoginUser, summaryOnly bool) ([]model.DropsItem, int64, error) {
	query := s.baseVisibleQuery(loginUser).Model(&model.DropsItem{})
	if !summaryOnly {
		query = query.Preload("Photos", func(tx *gorm.DB) *gorm.DB {
			return tx.Order("sort asc, id asc")
		})
	}

	scopeType := strings.TrimSpace(strings.ToLower(listDTO.ScopeType))
	switch scopeType {
	case model.DropsScopeShared:
		query = query.Where("scope_type = ?", model.DropsScopeShared)
	case model.DropsScopePersonal:
		query = query.Where("scope_type = ? AND owner_user_id = ?", model.DropsScopePersonal, loginUser.ID)
	}
	if category := normalizeDropsItemCategory(listDTO.Category); category != "" {
		query = query.Where("category = ?", category)
	}
	if keyword := strings.TrimSpace(listDTO.Keyword); keyword != "" {
		like := "%" + keyword + "%"
		query = query.Where("(name LIKE ? OR location LIKE ? OR remark LIKE ?)", like, like, like)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	items := make([]model.DropsItem, 0, listDTO.GetLimit())
	err := query.
		Order("CASE WHEN expire_at IS NULL THEN 1 ELSE 0 END ASC").
		Order("expire_at ASC").
		Order("updated_at DESC").
		Offset((listDTO.GetPage() - 1) * listDTO.GetLimit()).
		Limit(listDTO.GetLimit()).
		Find(&items).Error
	return items, total, err
}

func (s *DropsItemService) GetByID(id uint, loginUser model.LoginUser) (model.DropsItem, error) {
	var item model.DropsItem
	err := global.DB.Preload("Photos", func(tx *gorm.DB) *gorm.DB {
		return tx.Order("sort asc, id asc")
	}).First(&item, id).Error
	if err != nil {
		return model.DropsItem{}, err
	}
	if !s.canAccessItem(item, loginUser) {
		return model.DropsItem{}, errors.New("无权限访问该物资")
	}
	return item, nil
}

func (s *DropsItemService) Create(loginUser model.LoginUser, updateDTO *dto.DropsItemUpsertDTO, files []*multipart.FileHeader, loc *time.Location) (model.DropsItem, error) {
	normalized, err := s.prepareItemUpsert(nil, loginUser, updateDTO, loc)
	if err != nil {
		return model.DropsItem{}, err
	}
	if len(files) == 0 {
		return model.DropsItem{}, errors.New("请至少拍摄一张物资照片")
	}
	if len(files) > dropsMaxPhotoCount {
		return model.DropsItem{}, fmt.Errorf("物资照片最多上传 %d 张", dropsMaxPhotoCount)
	}

	ctx := context.Background()
	tx := global.DB.Begin()
	if tx.Error != nil {
		return model.DropsItem{}, tx.Error
	}

	folder := ""
	var createErr error
	defer func() {
		if createErr != nil {
			tx.Rollback()
			if folder != "" {
				_ = s.deleteQuarkFolder(ctx, folder)
			}
		}
	}()

	if createErr = tx.Create(normalized).Error; createErr != nil {
		return model.DropsItem{}, createErr
	}
	folder = dropsPhotoFolder(normalized.Category, normalized.ID)
	if createErr = s.addPhotosTx(ctx, tx, normalized, files, folder); createErr != nil {
		return model.DropsItem{}, createErr
	}
	if createErr = tx.Commit().Error; createErr != nil {
		return model.DropsItem{}, createErr
	}
	created, err := s.GetByID(normalized.ID, loginUser)
	if err != nil {
		return model.DropsItem{}, err
	}
	TriggerDropsReminderRescan(loc)
	return created, nil
}

func (s *DropsItemService) Update(id uint, loginUser model.LoginUser, updateDTO *dto.DropsItemUpsertDTO, loc *time.Location) (model.DropsItem, error) {
	item, err := s.GetByID(id, loginUser)
	if err != nil {
		return model.DropsItem{}, err
	}
	updated, err := s.prepareItemUpsert(&item, loginUser, updateDTO, loc)
	if err != nil {
		return model.DropsItem{}, err
	}

	tx := global.DB.Begin()
	if tx.Error != nil {
		return model.DropsItem{}, tx.Error
	}
	ctx := context.Background()
	var updateErr error
	defer func() {
		if updateErr != nil {
			tx.Rollback()
		}
	}()

	if item.Category != updated.Category && item.PhotoCount > 0 {
		if updateErr = s.moveItemPhotoFolder(ctx, item.Category, updated.Category, item.ID); updateErr != nil {
			return model.DropsItem{}, updateErr
		}
		if updateErr = s.refreshPhotoPathsTx(tx, item.ID, updated.Category); updateErr != nil {
			return model.DropsItem{}, updateErr
		}
	}

	if updateErr = tx.Model(&model.DropsItem{}).Where("id = ?", item.ID).Updates(map[string]any{
		"scope_type":    updated.ScopeType,
		"owner_user_id": updated.OwnerUserID,
		"updated_by":    updated.UpdatedBy,
		"category":      updated.Category,
		"name":          updated.Name,
		"location":      updated.Location,
		"expire_at":     updated.ExpireAt,
		"remark":        updated.Remark,
		"reminder_days": updated.ReminderDays,
		"enabled":       updated.Enabled,
	}).Error; updateErr != nil {
		return model.DropsItem{}, updateErr
	}

	if updateErr = tx.Commit().Error; updateErr != nil {
		return model.DropsItem{}, updateErr
	}
	updatedItem, err := s.GetByID(item.ID, loginUser)
	if err != nil {
		return model.DropsItem{}, err
	}
	TriggerDropsReminderRescan(loc)
	return updatedItem, nil
}

func (s *DropsItemService) AddPhotos(itemID uint, loginUser model.LoginUser, files []*multipart.FileHeader) (model.DropsItem, error) {
	item, err := s.GetByID(itemID, loginUser)
	if err != nil {
		return model.DropsItem{}, err
	}
	if len(files) == 0 {
		return model.DropsItem{}, errors.New("请至少拍摄一张物资照片")
	}
	if item.PhotoCount+len(files) > dropsMaxPhotoCount {
		return model.DropsItem{}, fmt.Errorf("物资照片最多上传 %d 张", dropsMaxPhotoCount)
	}

	tx := global.DB.Begin()
	if tx.Error != nil {
		return model.DropsItem{}, tx.Error
	}
	var addErr error
	defer func() {
		if addErr != nil {
			tx.Rollback()
		}
	}()

	if addErr = s.addPhotosTx(context.Background(), tx, &item, files, dropsPhotoFolder(item.Category, item.ID)); addErr != nil {
		return model.DropsItem{}, addErr
	}
	if addErr = tx.Commit().Error; addErr != nil {
		return model.DropsItem{}, addErr
	}
	return s.GetByID(item.ID, loginUser)
}

func (s *DropsItemService) DeletePhoto(itemID, photoID uint, loginUser model.LoginUser) error {
	item, err := s.GetByID(itemID, loginUser)
	if err != nil {
		return err
	}
	if len(item.Photos) <= 1 {
		return errors.New("物资至少保留一张照片")
	}
	var target model.DropsItemPhoto
	found := false
	for _, photo := range item.Photos {
		if photo.ID == photoID {
			target = photo
			found = true
			break
		}
	}
	if !found {
		return errors.New("照片不存在")
	}

	tx := global.DB.Begin()
	if tx.Error != nil {
		return tx.Error
	}
	var deleteErr error
	defer func() {
		if deleteErr != nil {
			tx.Rollback()
		}
	}()

	if deleteErr = tx.Delete(&model.DropsItemPhoto{}, target.ID).Error; deleteErr != nil {
		return deleteErr
	}
	if deleteErr = s.deleteQuarkFile(context.Background(), target.FilePath); deleteErr != nil {
		return deleteErr
	}
	if deleteErr = s.syncItemPhotoSummaryTx(tx, itemID); deleteErr != nil {
		return deleteErr
	}
	return tx.Commit().Error
}

func (s *DropsItemService) Delete(id uint, loginUser model.LoginUser) error {
	item, err := s.GetByID(id, loginUser)
	if err != nil {
		return err
	}
	tx := global.DB.Begin()
	if tx.Error != nil {
		return tx.Error
	}
	var deleteErr error
	defer func() {
		if deleteErr != nil {
			tx.Rollback()
		}
	}()

	if item.PhotoCount > 0 {
		if deleteErr = s.deleteQuarkFolder(context.Background(), dropsPhotoFolder(item.Category, item.ID)); deleteErr != nil {
			return deleteErr
		}
	}
	if deleteErr = tx.Where("item_id = ?", item.ID).Delete(&model.DropsItemPhoto{}).Error; deleteErr != nil {
		return deleteErr
	}
	if deleteErr = tx.Delete(&model.DropsItem{}, item.ID).Error; deleteErr != nil {
		return deleteErr
	}
	return tx.Commit().Error
}

func (s *DropsItemService) SuggestLocations(keyword string, loginUser model.LoginUser) ([]string, error) {
	type row struct {
		Location string `gorm:"column:location"`
	}
	query := s.baseVisibleQuery(loginUser).Model(&model.DropsItem{}).
		Select("location").
		Where("location <> ''")
	if keyword = strings.TrimSpace(keyword); keyword != "" {
		query = query.Where("location LIKE ?", "%"+keyword+"%")
	}
	rows := make([]row, 0, 10)
	if err := query.Group("location").Order("MAX(updated_at) DESC").Limit(10).Scan(&rows).Error; err != nil {
		return nil, err
	}
	result := make([]string, 0, len(rows))
	for _, row := range rows {
		if strings.TrimSpace(row.Location) != "" {
			result = append(result, row.Location)
		}
	}
	return result, nil
}

func (s *DropsItemService) ListReminderCandidates() ([]model.DropsItem, error) {
	items := make([]model.DropsItem, 0, 50)
	err := global.DB.Model(&model.DropsItem{}).
		Where("expire_at IS NOT NULL").
		Where("enabled = ?", true).
		Find(&items).Error
	return items, err
}

func (s *DropsItemService) BuildReminderMessages(now time.Time, loc *time.Location) ([]model.AppMessage, error) {
	items, err := s.ListReminderCandidates()
	if err != nil {
		return nil, err
	}
	_, reminderDays, err := configuredDropsItemReminderDays()
	if err != nil {
		return nil, err
	}
	recipients, err := (&AppMessageService{}).ListRecipientUserIDs()
	if err != nil {
		return nil, err
	}
	result := make([]model.AppMessage, 0, 16)
	for _, item := range items {
		if item.ExpireAt == nil {
			continue
		}
		days := dropsDaysUntil(now, *item.ExpireAt, loc)
		if !containsInt(reminderDays, days) {
			continue
		}
		for _, recipientID := range s.resolveRecipients(item.ScopeType, item.OwnerUserID, recipients) {
			sourceKey := fmt.Sprintf(
				"%s:%d:%s:%d:%d",
				model.DropsBizTypeItem,
				item.ID,
				item.ExpireAt.In(loc).Format("2006-01-02"),
				days,
				recipientID,
			)
			result = append(result, model.AppMessage{
				OwnerUserID: recipientID,
				Source:      model.AppMessageSourceDrops,
				SourceKey:   sourceKey,
				MessageType: model.AppMessageTypeDropsItemExpire,
				BizType:     model.DropsBizTypeItem,
				BizID:       item.ID,
				UniqueKey:   model.BuildAppMessageUniqueKey(model.AppMessageSourceDrops, sourceKey),
				Title:       s.buildItemReminderTitle(item, days),
				Summary:     s.buildItemReminderSummary(item, loc),
				TriggerDate: dropsStartOfDay(*item.ExpireAt, loc),
			})
		}
	}
	return result, nil
}

func (s *DropsItemService) buildItemReminderTitle(item model.DropsItem, days int) string {
	if days == 0 {
		return fmt.Sprintf("%s 今天到期", item.Name)
	}
	return fmt.Sprintf("%s 将在 %d 天后到期", item.Name, days)
}

func (s *DropsItemService) buildItemReminderSummary(item model.DropsItem, loc *time.Location) string {
	parts := []string{}
	if item.Location != "" {
		parts = append(parts, "位置："+item.Location)
	}
	if item.ExpireAt != nil {
		parts = append(parts, "到期日："+item.ExpireAt.In(loc).Format("2006-01-02"))
	}
	return strings.Join(parts, "；")
}

func (s *DropsItemService) baseVisibleQuery(loginUser model.LoginUser) *gorm.DB {
	return global.DB.Where("scope_type = ? OR (scope_type = ? AND owner_user_id = ?)", model.DropsScopeShared, model.DropsScopePersonal, loginUser.ID)
}

func (s *DropsItemService) canAccessItem(item model.DropsItem, loginUser model.LoginUser) bool {
	if item.ScopeType == model.DropsScopeShared {
		return true
	}
	return item.OwnerUserID == loginUser.ID
}

func (s *DropsItemService) prepareItemUpsert(existing *model.DropsItem, loginUser model.LoginUser, updateDTO *dto.DropsItemUpsertDTO, loc *time.Location) (*model.DropsItem, error) {
	category := normalizeDropsItemCategory(updateDTO.Category)
	if category == "" {
		return nil, errors.New("物资分类无效")
	}
	reminderRaw, _, err := configuredDropsItemReminderDays()
	if err != nil {
		return nil, err
	}
	expireAt, err := parseDateOnlyInLocation(updateDTO.ExpireAt, loc)
	if err != nil {
		return nil, err
	}
	item := &model.DropsItem{}
	if existing != nil {
		*item = *existing
	}
	updateDTO.ApplyToModel(item)
	item.ScopeType = normalizeDropsScope(updateDTO.ScopeType)
	item.Category = category
	item.Name = strings.TrimSpace(item.Name)
	item.Location = strings.TrimSpace(item.Location)
	item.Remark = strings.TrimSpace(item.Remark)
	item.ReminderDays = reminderRaw
	item.ExpireAt = expireAt
	item.OwnerUserID = loginUser.ID
	if item.CreatedBy == 0 {
		item.CreatedBy = loginUser.ID
	}
	item.UpdatedBy = loginUser.ID
	if updateDTO.Enabled == nil {
		if existing == nil {
			item.Enabled = true
		}
	} else {
		item.Enabled = *updateDTO.Enabled
	}
	if item.Name == "" {
		return nil, errors.New("物资名称不能为空")
	}
	return item, nil
}

func (s *DropsItemService) addPhotosTx(ctx context.Context, tx *gorm.DB, item *model.DropsItem, files []*multipart.FileHeader, folder string) error {
	var currentMaxSort int
	if err := tx.Model(&model.DropsItemPhoto{}).
		Where("item_id = ?", item.ID).
		Select("COALESCE(MAX(sort), 0)").
		Scan(&currentMaxSort).Error; err != nil {
		return err
	}
	for index, file := range files {
		ext := path.Ext(file.Filename)
		if ext == "" {
			ext = ".jpg"
		}
		fileName := fmt.Sprintf("%02d_%d%s", currentMaxSort+index+1, time.Now().UnixMilli(), ext)
		if err := (&QuarkFsService{}).uploadFileToTarget(ctx, dropsUploadApplication, folder+"/", file, fileName, 0); err != nil {
			return fmt.Errorf("上传物资照片失败: %w", err)
		}
		filePath := dropsNormalizeQuarkPath(folder + "/" + fileName)
		photo := model.DropsItemPhoto{
			ItemID:   item.ID,
			Sort:     currentMaxSort + index + 1,
			FileName: fileName,
			FilePath: filePath,
			URL:      dropsPhotoURL(filePath),
			Size:     file.Size,
			IsCover:  item.PhotoCount == 0 && index == 0,
		}
		if err := tx.Create(&photo).Error; err != nil {
			return err
		}
	}
	return s.syncItemPhotoSummaryTx(tx, item.ID)
}

func (s *DropsItemService) syncItemPhotoSummaryTx(tx *gorm.DB, itemID uint) error {
	photos := make([]model.DropsItemPhoto, 0, 8)
	if err := tx.Where("item_id = ?", itemID).Order("sort asc, id asc").Find(&photos).Error; err != nil {
		return err
	}
	coverURL := ""
	coverID := uint(0)
	if len(photos) > 0 {
		coverURL = photos[0].URL
		coverID = photos[0].ID
	}
	if err := tx.Model(&model.DropsItemPhoto{}).Where("item_id = ?", itemID).Update("is_cover", false).Error; err != nil {
		return err
	}
	if coverID != 0 {
		if err := tx.Model(&model.DropsItemPhoto{}).Where("id = ?", coverID).Update("is_cover", true).Error; err != nil {
			return err
		}
	}
	return tx.Model(&model.DropsItem{}).Where("id = ?", itemID).Updates(map[string]any{
		"cover_url":   coverURL,
		"photo_count": len(photos),
	}).Error
}

func (s *DropsItemService) refreshPhotoPathsTx(tx *gorm.DB, itemID uint, category string) error {
	photos := make([]model.DropsItemPhoto, 0, 8)
	if err := tx.Where("item_id = ?", itemID).Order("sort asc, id asc").Find(&photos).Error; err != nil {
		return err
	}
	for _, photo := range photos {
		filePath := dropsNormalizeQuarkPath(dropsPhotoFolder(category, itemID) + "/" + photo.FileName)
		if err := tx.Model(&model.DropsItemPhoto{}).Where("id = ?", photo.ID).Updates(map[string]any{
			"file_path": filePath,
			"url":       dropsPhotoURL(filePath),
		}).Error; err != nil {
			return err
		}
	}
	return s.syncItemPhotoSummaryTx(tx, itemID)
}

func (s *DropsItemService) moveItemPhotoFolder(ctx context.Context, oldCategory, newCategory string, itemID uint) error {
	if oldCategory == newCategory {
		return nil
	}
	quarkService := &QuarkFsService{}
	client, err := newManagedQuarkClient()
	if err != nil {
		return err
	}
	sourcePath := "/upload" + dropsPhotoFolder(oldCategory, itemID)
	_, sourceEntry, err := quarkService.resolveAbsolutePath(ctx, client, sourcePath, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return nil
		}
		return err
	}
	targetParent := path.Join("/upload", dropsPhotoRootDir, newCategory)
	_, targetEntry, err := quarkService.resolveAbsolutePath(ctx, client, targetParent, true)
	if err != nil {
		return err
	}
	return client.move(ctx, sourceEntry.Fid, targetEntry.Fid)
}

func (s *DropsItemService) deleteQuarkFolder(ctx context.Context, folder string) error {
	quarkService := &QuarkFsService{}
	client, err := newManagedQuarkClient()
	if err != nil {
		return err
	}
	_, entry, err := quarkService.resolveAbsolutePath(ctx, client, "/upload"+folder, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return nil
		}
		return err
	}
	return client.delete(ctx, entry.Fid)
}

func (s *DropsItemService) deleteQuarkFile(ctx context.Context, filePath string) error {
	quarkService := &QuarkFsService{}
	client, err := newManagedQuarkClient()
	if err != nil {
		return err
	}
	_, entry, err := quarkService.resolveAbsolutePath(ctx, client, "/upload"+filePath, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return nil
		}
		return err
	}
	return client.delete(ctx, entry.Fid)
}

func (s *DropsItemService) resolveRecipients(scopeType string, ownerUserID uint, userIDs []uint) []uint {
	if scopeType == model.DropsScopePersonal {
		return []uint{ownerUserID}
	}
	return userIDs
}
