package service

import (
	"errors"
	"ohome/global"
	"ohome/model"
	"path"
	"strings"

	"gorm.io/gorm"
)

type historyMutationMode string

const (
	historyMutationRename historyMutationMode = "rename"
	historyMutationMove   historyMutationMode = "move"
	historyMutationDelete historyMutationMode = "delete"
)

type historyMutationOptions struct {
	Mode              historyMutationMode
	UserID            uint
	SourceApplication string
	TargetApplication string
	SourcePath        string
	TargetPath        string
}

func (s *QuarkFsService) syncHistoryAfterRename(userID uint, application, oldPath, newPath string) error {
	_, err := s.applyHistoryMutation(historyMutationOptions{
		Mode:              historyMutationRename,
		UserID:            userID,
		SourceApplication: strings.TrimSpace(application),
		TargetApplication: strings.TrimSpace(application),
		SourcePath:        s.normalizeHistoryPath(oldPath),
		TargetPath:        s.normalizeHistoryPath(newPath),
	})
	return err
}

func (s *QuarkFsService) syncHistoryAfterMove(userID uint, sourceApplication, targetApplication, sourcePath, targetPath string) error {
	_, err := s.applyHistoryMutation(historyMutationOptions{
		Mode:              historyMutationMove,
		UserID:            userID,
		SourceApplication: strings.TrimSpace(sourceApplication),
		TargetApplication: strings.TrimSpace(targetApplication),
		SourcePath:        s.normalizeHistoryPath(sourcePath),
		TargetPath:        s.normalizeHistoryPath(targetPath),
	})
	return err
}

func (s *QuarkFsService) syncHistoryAfterDelete(userID uint, application, deletedPath string) ([]model.UserMediaHistory, error) {
	return s.applyHistoryMutation(historyMutationOptions{
		Mode:              historyMutationDelete,
		UserID:            userID,
		SourceApplication: strings.TrimSpace(application),
		SourcePath:        s.normalizeHistoryPath(deletedPath),
	})
}

func (s *QuarkFsService) applyHistoryMutation(opts historyMutationOptions) ([]model.UserMediaHistory, error) {
	if opts.UserID == 0 {
		return nil, errors.New("用户ID不能为空")
	}
	if opts.SourcePath == "" || opts.SourcePath == "/" {
		return nil, nil
	}
	if opts.Mode != historyMutationDelete && (opts.TargetPath == "" || opts.TargetPath == "/") {
		return nil, errors.New("目标路径不能为空")
	}

	mutated := make([]model.UserMediaHistory, 0)
	err := global.DB.Transaction(func(tx *gorm.DB) error {
		records, queryErr := s.queryHistoryCandidates(tx, opts)
		if queryErr != nil {
			return queryErr
		}
		for i := range records {
			original := records[i]
			original.NormalizePlaybackFields()

			next, affected := s.projectHistoryRecord(original, opts)
			if !affected {
				continue
			}

			mutated = append(mutated, original)
			if opts.Mode == historyMutationDelete {
				if err := tx.Delete(&model.UserMediaHistory{}, original.ID).Error; err != nil {
					return err
				}
				continue
			}

			if err := tx.Save(&next).Error; err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return nil, err
	}
	return mutated, nil
}

func (s *QuarkFsService) queryHistoryCandidates(tx *gorm.DB, opts historyMutationOptions) ([]model.UserMediaHistory, error) {
	query := tx.Model(&model.UserMediaHistory{}).Where("user_id = ?", opts.UserID)
	if app := strings.TrimSpace(opts.SourceApplication); app != "" {
		query = query.Where("application_type = ?", app)
	}

	oldPath := opts.SourcePath
	oldPathLike := oldPath + "/%"
	parentPath, baseName := s.splitHistoryPath(oldPath)

	query = query.Where(
		"(folder_path = ? OR folder_path LIKE ? OR item_path = ? OR item_path LIKE ? OR (folder_path = ? AND item_title = ?))",
		oldPath,
		oldPathLike,
		oldPath,
		oldPathLike,
		parentPath,
		baseName,
	)

	var records []model.UserMediaHistory
	err := query.Find(&records).Error
	return records, err
}

func (s *QuarkFsService) projectHistoryRecord(history model.UserMediaHistory, opts historyMutationOptions) (model.UserMediaHistory, bool) {
	folderPath := s.normalizeHistoryPath(history.FolderPath)
	itemPath := s.normalizeHistoryPath(history.ItemPath)
	affectedFolder := s.isPathEqualOrDescendant(folderPath, opts.SourcePath)
	affectedItem := s.isPathEqualOrDescendant(itemPath, opts.SourcePath)

	if opts.Mode == historyMutationDelete {
		return history, affectedFolder || affectedItem
	}

	newFolderPath, folderChanged := s.replaceHistoryPathPrefix(folderPath, opts.SourcePath, opts.TargetPath)
	newItemPath, itemChanged := s.replaceHistoryPathPrefix(itemPath, opts.SourcePath, opts.TargetPath)
	if !folderChanged && !itemChanged {
		return history, false
	}

	history.FolderPath = newFolderPath
	history.ItemPath = newItemPath
	if itemChanged {
		if title := strings.TrimSpace(path.Base(newItemPath)); title != "" && title != "." && title != "/" {
			history.ItemTitle = title
		}
	}
	if opts.Mode == historyMutationMove && strings.TrimSpace(opts.TargetApplication) != "" {
		history.ApplicationType = strings.TrimSpace(opts.TargetApplication)
	}

	history.PrepareForSave()
	return history, true
}

func (s *QuarkFsService) rollbackDeletedHistory(records []model.UserMediaHistory) error {
	if len(records) == 0 {
		return nil
	}

	return global.DB.Transaction(func(tx *gorm.DB) error {
		for i := range records {
			record := records[i]
			record.PrepareForSave()
			updates := map[string]any{
				"user_id":          record.UserID,
				"application_type": record.ApplicationType,
				"folder_path":      record.FolderPath,
				"item_title":       record.ItemTitle,
				"item_path":        record.ItemPath,
				"position_ms":      record.PositionMs,
				"duration_ms":      record.DurationMs,
				"cover_url":        record.CoverURL,
				"extra":            record.Extra,
				"unique_key":       record.UniqueKey,
				"last_played_at":   record.LastPlayedAt,
				"deleted_at":       nil,
			}
			if err := tx.Unscoped().Model(&model.UserMediaHistory{}).Where("id = ?", record.ID).Updates(updates).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *QuarkFsService) resolveSourceApplicationAndHistoryPath(sourcePath, fallbackApplication, fallbackRootPath string, userID uint) (string, string, error) {
	configs, err := s.listAllQuarkConfigs()
	if err != nil {
		return "", "", err
	}
	return s.resolveSourceApplicationAndHistoryPathWithConfigs(sourcePath, fallbackApplication, fallbackRootPath, userID, configs)
}

func (s *QuarkFsService) resolveSourceApplicationAndHistoryPathWithConfigs(
	sourcePath, fallbackApplication, fallbackRootPath string,
	userID uint,
	configs []model.QuarkConfig,
) (string, string, error) {
	fullPath := s.normalizeHistoryPath(sourcePath)
	if fullPath == "" || fullPath == "/" {
		return "", "", errors.New("移动源路径不能为空")
	}

	matchedApp := strings.TrimSpace(fallbackApplication)
	matchedRoot := resolveQuarkRootPathForUser(fallbackApplication, fallbackRootPath, userID)
	matchedLen := -1

	for i := range configs {
		app := strings.TrimSpace(configs[i].Application)
		if app == "" {
			continue
		}
		root := resolveQuarkRootPathForUser(app, configs[i].RootPath, userID)
		if root == "/" {
			continue
		}
		if !s.isPathEqualOrDescendant(fullPath, root) {
			continue
		}
		if len(root) > matchedLen {
			matchedLen = len(root)
			matchedApp = app
			matchedRoot = root
		}
	}

	if matchedApp == "" {
		matchedApp = strings.TrimSpace(fallbackApplication)
	}
	historyPath := s.resolveHistoryPath(fullPath, matchedRoot)
	if historyPath == "" {
		return "", "", errors.New("无法解析移动源路径")
	}
	return matchedApp, historyPath, nil
}

func (s *QuarkFsService) listAllQuarkConfigs() ([]model.QuarkConfig, error) {
	var configs []model.QuarkConfig
	err := global.DB.Model(&model.QuarkConfig{}).Find(&configs).Error
	return configs, err
}

func (s *QuarkFsService) isApplicationRootPath(sourcePath string) (bool, error) {
	configs, err := s.listAllQuarkConfigs()
	if err != nil {
		return false, err
	}
	return s.isApplicationRootPathWithConfigs(sourcePath, configs, 0), nil
}

func (s *QuarkFsService) isApplicationRootPathForUser(sourcePath string, userID uint) (bool, error) {
	configs, err := s.listAllQuarkConfigs()
	if err != nil {
		return false, err
	}
	return s.isApplicationRootPathWithConfigs(sourcePath, configs, userID), nil
}

func (s *QuarkFsService) isApplicationRootPathWithConfigs(sourcePath string, configs []model.QuarkConfig, userID uint) bool {
	normalizedSource := s.normalizeAbsoluteSourcePath(sourcePath)
	if normalizedSource == "" || normalizedSource == "/" {
		return false
	}

	for i := range configs {
		root := resolveQuarkRootPathForUser(configs[i].Application, configs[i].RootPath, userID)
		if root == "" || root == "/" {
			continue
		}
		if normalizedSource == root {
			return true
		}
	}
	return false
}

func (s *QuarkFsService) resolveHistoryPath(rawPath, rootPath string) string {
	normalized := s.normalizeHistoryPath(rawPath)
	if normalized == "" {
		return ""
	}

	root := s.normalizeConfiguredRootPath(rootPath)
	if root == "" || root == "/" {
		return normalized
	}
	if normalized == root {
		return "/"
	}
	prefix := root + "/"
	if strings.HasPrefix(normalized, prefix) {
		trimmed := strings.TrimPrefix(normalized, prefix)
		if strings.TrimSpace(trimmed) == "" {
			return "/"
		}
		return "/" + strings.TrimLeft(trimmed, "/")
	}
	return normalized
}

func (s *QuarkFsService) normalizeHistoryPath(value string) string {
	normalized := strings.TrimSpace(strings.ReplaceAll(value, "\\", "/"))
	if normalized == "" {
		return ""
	}
	if !strings.HasPrefix(normalized, "/") {
		normalized = "/" + normalized
	}
	cleaned := path.Clean(normalized)
	if cleaned == "." {
		return "/"
	}
	return cleaned
}

func (s *QuarkFsService) isPathEqualOrDescendant(candidate, target string) bool {
	normalizedCandidate := s.normalizeHistoryPath(candidate)
	normalizedTarget := s.normalizeHistoryPath(target)
	if normalizedCandidate == "" || normalizedTarget == "" {
		return false
	}
	if normalizedCandidate == normalizedTarget {
		return true
	}
	if normalizedTarget == "/" {
		return strings.HasPrefix(normalizedCandidate, "/")
	}
	return strings.HasPrefix(normalizedCandidate, normalizedTarget+"/")
}

func (s *QuarkFsService) replaceHistoryPathPrefix(value, oldPrefix, newPrefix string) (string, bool) {
	normalizedValue := s.normalizeHistoryPath(value)
	normalizedOldPrefix := s.normalizeHistoryPath(oldPrefix)
	normalizedNewPrefix := s.normalizeHistoryPath(newPrefix)
	if normalizedValue == "" || normalizedOldPrefix == "" || normalizedNewPrefix == "" {
		return normalizedValue, false
	}
	if normalizedValue == normalizedOldPrefix {
		return normalizedNewPrefix, true
	}
	if normalizedOldPrefix == "/" {
		return normalizedValue, false
	}
	prefix := normalizedOldPrefix + "/"
	if !strings.HasPrefix(normalizedValue, prefix) {
		return normalizedValue, false
	}
	suffix := strings.TrimPrefix(normalizedValue, normalizedOldPrefix)
	next := path.Clean(normalizedNewPrefix + suffix)
	return s.normalizeHistoryPath(next), true
}

func (s *QuarkFsService) splitHistoryPath(pathValue string) (string, string) {
	dir, name := path.Split(pathValue)
	dir = s.normalizeHistoryPath(dir)
	if dir == "" {
		dir = "/"
	}
	name = strings.Trim(strings.TrimSpace(name), "/")
	return dir, name
}
