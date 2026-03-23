package service

import (
	"context"
	"errors"
	"fmt"
	"mime/multipart"
	"net/url"
	"ohome/model"
	"ohome/service/dto"
	"path"
	"strings"
	"time"
)

type QuarkFsService struct {
	BaseService
}

type QuarkProxyMeta struct {
	Filename  string
	Size      int64
	UpdatedAt int64
}

func (s *QuarkFsService) ListFiles(pathDTO *dto.QuarkPathDTO) ([]dto.QuarkFsInfo, error) {
	logQuarkWarnf("[quarkFs:list] start application=%s rawPath=%q", strings.TrimSpace(pathDTO.Application), strings.TrimSpace(pathDTO.Path))
	client, err := newManagedQuarkClient()
	if err != nil {
		logQuarkWarnf("[quarkFs:list] init client failed application=%s err=%v", strings.TrimSpace(pathDTO.Application), err)
		return nil, err
	}
	ctx := context.Background()

	_, rootEntry, rootPath, err := s.resolveApplicationRoot(ctx, client, pathDTO.Application, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			logQuarkWarnf("[quarkFs:list] application root not found application=%s rootPath=%s", strings.TrimSpace(pathDTO.Application), rootPath)
			return nil, errors.New("应用根目录不存在")
		}
		logQuarkWarnf("[quarkFs:list] resolve application root failed application=%s err=%v", strings.TrimSpace(pathDTO.Application), err)
		return nil, err
	}
	logQuarkWarnf("[quarkFs:list] resolved root application=%s rootPath=%s rootFid=%s", strings.TrimSpace(pathDTO.Application), rootPath, strings.TrimSpace(rootEntry.Fid))

	targetEntry := rootEntry
	clientPath := s.normalizeClientPath(pathDTO.Path)
	logQuarkWarnf("[quarkFs:list] normalized path application=%s clientPath=%s", strings.TrimSpace(pathDTO.Application), clientPath)
	if clientPath != "/" {
		_, entry, err := s.resolveRelativePath(ctx, client, rootEntry.Fid, clientPath, false)
		if err != nil {
			if errors.Is(err, errQuarkEntryNotFound) {
				logQuarkWarnf("[quarkFs:list] target path not found application=%s rootFid=%s clientPath=%s", strings.TrimSpace(pathDTO.Application), strings.TrimSpace(rootEntry.Fid), clientPath)
				return nil, errors.New("目录不存在")
			}
			logQuarkWarnf("[quarkFs:list] resolve target path failed application=%s clientPath=%s err=%v", strings.TrimSpace(pathDTO.Application), clientPath, err)
			return nil, err
		}
		if !entry.IsDir() {
			logQuarkWarnf("[quarkFs:list] target is not dir application=%s clientPath=%s fid=%s", strings.TrimSpace(pathDTO.Application), clientPath, strings.TrimSpace(entry.Fid))
			return nil, errors.New("path 不是目录")
		}
		targetEntry = entry
	}

	logQuarkWarnf("[quarkFs:list] listing application=%s clientPath=%s targetFid=%s targetName=%s", strings.TrimSpace(pathDTO.Application), clientPath, strings.TrimSpace(targetEntry.Fid), targetEntry.Name())
	page := pathDTO.Page
	size := pathDTO.Size
	sortExpr := quarkListSortByName
	if clientPath == "/" {
		sortExpr = quarkListSortByUpdated
	}

	var entries []quarkDriveFile
	if size > 0 {
		entries, _, err = client.listPageWithSort(
			ctx,
			targetEntry.Fid,
			page,
			size,
			sortExpr,
		)
	} else {
		entries, err = client.listAllWithSort(ctx, targetEntry.Fid, sortExpr)
	}
	if err != nil {
		logQuarkWarnf("[quarkFs:list] list target failed application=%s clientPath=%s targetFid=%s page=%d size=%d err=%v", strings.TrimSpace(pathDTO.Application), clientPath, strings.TrimSpace(targetEntry.Fid), page, size, err)
		return nil, err
	}
	logQuarkWarnf("[quarkFs:list] list target success application=%s clientPath=%s targetFid=%s page=%d size=%d count=%d sample=%s", strings.TrimSpace(pathDTO.Application), clientPath, strings.TrimSpace(targetEntry.Fid), page, size, len(entries), summarizeQuarkEntryNames(entries, 8))

	files := make([]dto.QuarkFsInfo, 0, len(entries))
	for _, entry := range entries {
		name := entry.Name()
		if name == "" {
			continue
		}
		filePath := s.buildPath(clientPath, name)
		streamURL := ""
		downloadURL := ""
		if !entry.IsDir() {
			baseURL := "/api/v1/public/quarkFs/" + url.PathEscape(pathDTO.Application) + "/files/stream?path=" + url.QueryEscape(filePath)
			streamURL = baseURL
			downloadURL = baseURL + "&download=true"
		}
		files = append(files, dto.QuarkFsInfo{
			Name:        name,
			Path:        filePath,
			StreamURL:   streamURL,
			DownloadURL: downloadURL,
			IsDir:       entry.IsDir(),
			Size:        entry.Size,
			UpdatedAt:   entry.UpdatedUnix(),
		})
	}

	logQuarkWarnf("[quarkFs:list] finish application=%s clientPath=%s responseCount=%d", strings.TrimSpace(pathDTO.Application), clientPath, len(files))
	return files, nil
}

func (s *QuarkFsService) GetFileMetadata(pathDTO *dto.QuarkPathDTO) (dto.QuarkFsMetaInfo, error) {
	client, err := newManagedQuarkClient()
	if err != nil {
		return dto.QuarkFsMetaInfo{}, err
	}
	ctx := context.Background()

	_, rootEntry, rootPath, err := s.resolveApplicationRoot(ctx, client, pathDTO.Application, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return dto.QuarkFsMetaInfo{}, errors.New("文件不存在")
		}
		return dto.QuarkFsMetaInfo{}, err
	}

	clientPath := s.normalizeClientPath(pathDTO.Path)
	entry := rootEntry
	if clientPath != "/" {
		_, entry, err = s.resolveRelativePath(ctx, client, rootEntry.Fid, clientPath, false)
		if err != nil {
			if errors.Is(err, errQuarkEntryNotFound) {
				return dto.QuarkFsMetaInfo{}, errors.New("文件不存在")
			}
			return dto.QuarkFsMetaInfo{}, err
		}
	}

	name := entry.Name()
	if name == "" {
		name = s.displayNameForRoot(rootPath)
	}

	return dto.QuarkFsMetaInfo{
		ID:           strings.TrimSpace(entry.Fid),
		Name:         name,
		Path:         clientPath,
		IsDir:        entry.IsDir(),
		Size:         entry.Size,
		UpdatedAt:    entry.UpdatedUnix(),
		CreatedAt:    entry.CreatedUnix(),
		Modified:     entry.UpdatedRaw(),
		Created:      entry.CreatedRaw(),
		Sign:         "",
		Thumb:        strings.TrimSpace(entry.Thumbnail),
		Type:         entry.Category,
		HashInfoRaw:  "",
		HashInfo:     nil,
		MountDetails: map[string]any{},
	}, nil
}

func (s *QuarkFsService) RenameFile(renameDTO *dto.QuarkRenameDTO, userID uint) error {
	rawPath := strings.TrimSpace(renameDTO.Path)
	if rawPath == "" || rawPath == "/" {
		return errors.New("path 不能为空")
	}

	newName := strings.TrimSpace(renameDTO.NewName)
	if newName == "" {
		return errors.New("newName 不能为空")
	}

	client, err := newManagedQuarkClient()
	if err != nil {
		return err
	}
	ctx := context.Background()

	config, rootEntry, _, err := s.resolveApplicationRoot(ctx, client, renameDTO.Application, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return errors.New("文件不存在")
		}
		return err
	}

	_, entry, err := s.resolveRelativePath(ctx, client, rootEntry.Fid, rawPath, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return errors.New("文件不存在")
		}
		return err
	}

	oldName := entry.Name()
	if oldName == "" || oldName == "." {
		return errors.New("文件名不存在")
	}

	if err := client.rename(ctx, entry.Fid, newName); err != nil {
		return err
	}

	oldHistoryPath := s.resolveHistoryPath(rawPath, config.RootPath)
	newHistoryPath := s.normalizeHistoryPath(path.Join(path.Dir(oldHistoryPath), newName))
	if err := s.syncHistoryAfterRename(userID, renameDTO.Application, oldHistoryPath, newHistoryPath); err != nil {
		rollbackErr := client.rename(ctx, entry.Fid, oldName)
		if rollbackErr != nil {
			return fmt.Errorf("更新播放历史失败：%v；且重命名回滚失败：%v", err, rollbackErr)
		}
		return fmt.Errorf("更新播放历史失败，重命名已回滚：%w", err)
	}

	return nil
}

func (s *QuarkFsService) DeleteFile(pathDTO *dto.QuarkPathDTO, userID uint) error {
	rawPath := strings.TrimSpace(pathDTO.Path)
	if rawPath == "" || rawPath == "/" {
		return errors.New("path 不能为空")
	}

	client, err := newManagedQuarkClient()
	if err != nil {
		return err
	}
	ctx := context.Background()

	config, rootEntry, _, err := s.resolveApplicationRoot(ctx, client, pathDTO.Application, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return errors.New("文件不存在")
		}
		return err
	}

	_, entry, err := s.resolveRelativePath(ctx, client, rootEntry.Fid, rawPath, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return errors.New("文件不存在")
		}
		return err
	}

	name := entry.Name()
	if name == "" {
		return errors.New("文件名不存在")
	}

	stagedName := s.buildDeleteStagedName(name)
	if err := client.rename(ctx, entry.Fid, stagedName); err != nil {
		return err
	}

	historyPath := s.resolveHistoryPath(rawPath, config.RootPath)
	deletedRecords, historyErr := s.syncHistoryAfterDelete(userID, pathDTO.Application, historyPath)
	if historyErr != nil {
		rollbackErr := client.rename(ctx, entry.Fid, name)
		if rollbackErr != nil {
			return fmt.Errorf("更新播放历史失败：%v；且删除回滚失败：%v", historyErr, rollbackErr)
		}
		return fmt.Errorf("更新播放历史失败，删除已回滚：%w", historyErr)
	}

	if err := client.delete(ctx, entry.Fid); err != nil {
		restoreErr := s.rollbackDeletedHistory(deletedRecords)
		rollbackErr := client.rename(ctx, entry.Fid, name)
		if restoreErr != nil || rollbackErr != nil {
			return fmt.Errorf("删除失败：%v；历史回滚错误：%v；文件回滚错误：%v", err, restoreErr, rollbackErr)
		}
		return err
	}

	return nil
}

func (s *QuarkFsService) MoveFile(pathDTO *dto.QuarkPathDTO, userID uint) error {
	config, err := quarkConfigDao.GetByApplication(pathDTO.Application)
	if err != nil {
		return err
	}
	config.RootPath = s.normalizeConfiguredRootPath(config.RootPath)

	targetDir := s.normalizeHistoryPath(s.buildPath("", config.RootPath))
	if targetDir == "/" {
		return errors.New("该应用未配置 rootPath，无法执行移动")
	}

	rawPath := strings.TrimSpace(pathDTO.Path)
	if rawPath == "" || rawPath == "/" {
		return errors.New("path 不能为空")
	}

	sourcePath := s.normalizeAbsoluteSourcePath(rawPath)
	if sourcePath == "/" {
		return errors.New("path 不能为空")
	}
	isAppRoot, err := s.isApplicationRootPath(sourcePath)
	if err != nil {
		return err
	}
	if isAppRoot {
		return errors.New("不允许移动应用根目录")
	}
	if sourcePath == targetDir {
		return errors.New("不允许移动应用根目录")
	}

	client, err := newManagedQuarkClient()
	if err != nil {
		return err
	}
	ctx := context.Background()

	sourceParentFid, sourceEntry, err := s.resolveAbsolutePath(ctx, client, sourcePath, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return errors.New("文件不存在")
		}
		return err
	}
	name := sourceEntry.Name()
	if name == "" {
		return errors.New("文件名不存在")
	}

	_, targetEntry, err := s.resolveAbsolutePath(ctx, client, targetDir, true)
	if err != nil {
		return err
	}
	if !targetEntry.IsDir() {
		return errors.New("目标路径不是目录")
	}

	if sourceParentFid == targetEntry.Fid {
		return nil
	}

	if err := client.move(ctx, sourceEntry.Fid, targetEntry.Fid); err != nil {
		return err
	}

	sourceApplication, sourceHistoryPath, err := s.resolveSourceApplicationAndHistoryPath(
		sourcePath,
		pathDTO.Application,
		config.RootPath,
	)
	if err != nil {
		rollbackErr := client.move(ctx, sourceEntry.Fid, sourceParentFid)
		if rollbackErr != nil {
			return fmt.Errorf("解析移动源路径失败：%v；且移动回滚失败：%v", err, rollbackErr)
		}
		return err
	}

	targetHistoryPath := s.resolveHistoryPath(path.Join(targetDir, name), config.RootPath)
	if err := s.syncHistoryAfterMove(
		userID,
		sourceApplication,
		pathDTO.Application,
		sourceHistoryPath,
		targetHistoryPath,
	); err != nil {
		rollbackErr := client.move(ctx, sourceEntry.Fid, sourceParentFid)
		if rollbackErr != nil {
			return fmt.Errorf("更新播放历史失败：%v；且移动回滚失败：%v", err, rollbackErr)
		}
		return fmt.Errorf("更新播放历史失败，移动已回滚：%w", err)
	}

	return nil
}

func (s *QuarkFsService) UploadFile(pathDTO *dto.QuarkPathDTO, fileHeader *multipart.FileHeader) error {
	return s.uploadFileToTarget(context.Background(), pathDTO.Application, pathDTO.Path, fileHeader, "")
}

func (s *QuarkFsService) StreamFile(ctx context.Context, pathDTO *dto.QuarkPathDTO, rangeHeader string) (*QuarkStreamResult, QuarkProxyMeta, error) {
	client, entry, filename, err := s.resolveFileForRead(pathDTO)
	if err != nil {
		return nil, QuarkProxyMeta{}, err
	}

	link, err := client.getDownloadLink(ctx, entry.Fid)
	if err != nil {
		return nil, QuarkProxyMeta{}, err
	}

	result, err := client.openConcurrentStream(ctx, link.URL, link.Size, rangeHeader, filename)
	if err != nil {
		return nil, QuarkProxyMeta{}, err
	}

	return result, QuarkProxyMeta{
		Filename:  filename,
		Size:      max(entry.Size, link.Size),
		UpdatedAt: entry.UpdatedUnix(),
	}, nil
}

func (s *QuarkFsService) DescribeFile(pathDTO *dto.QuarkPathDTO) (QuarkProxyMeta, error) {
	_, entry, filename, err := s.resolveFileForRead(pathDTO)
	if err != nil {
		return QuarkProxyMeta{}, err
	}
	return QuarkProxyMeta{
		Filename:  filename,
		Size:      entry.Size,
		UpdatedAt: entry.UpdatedUnix(),
	}, nil
}

func (s *QuarkFsService) resolveFileForRead(pathDTO *dto.QuarkPathDTO) (*quarkClient, quarkDriveFile, string, error) {
	client, err := newManagedQuarkClient()
	if err != nil {
		return nil, quarkDriveFile{}, "", err
	}
	ctx := context.Background()

	_, rootEntry, _, err := s.resolveApplicationRoot(ctx, client, pathDTO.Application, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return nil, quarkDriveFile{}, "", errors.New("文件不存在")
		}
		return nil, quarkDriveFile{}, "", err
	}

	_, entry, err := s.resolveRelativePath(ctx, client, rootEntry.Fid, pathDTO.Path, false)
	if err != nil {
		if errors.Is(err, errQuarkEntryNotFound) {
			return nil, quarkDriveFile{}, "", errors.New("文件不存在")
		}
		return nil, quarkDriveFile{}, "", err
	}
	if entry.IsDir() {
		return nil, quarkDriveFile{}, "", errors.New("path 不是文件")
	}

	filename := entry.Name()
	if filename == "" {
		filename = strings.Trim(strings.TrimSpace(path.Base(pathDTO.Path)), "/")
	}
	if filename == "" {
		return nil, quarkDriveFile{}, "", errors.New("文件名不存在")
	}

	return client, entry, filename, nil
}

func (s *QuarkFsService) uploadFileToTarget(ctx context.Context, application, targetPath string, fileHeader *multipart.FileHeader, overrideName string) error {
	config, err := quarkConfigDao.GetByApplication(application)
	if err != nil {
		return err
	}
	config.RootPath = s.normalizeConfiguredRootPath(config.RootPath)
	client, err := newManagedQuarkClient()
	if err != nil {
		return err
	}

	normalizedRaw := strings.TrimSpace(strings.ReplaceAll(targetPath, "\\", "/"))
	if normalizedRaw == "" {
		normalizedRaw = "/"
	}
	clientPath := s.normalizeClientPath(normalizedRaw)
	dirClientPath := clientPath
	fileName := strings.TrimSpace(overrideName)

	treatAsDir := clientPath == "/" || strings.HasSuffix(normalizedRaw, "/")
	if !treatAsDir {
		fullPath := s.buildPath(config.RootPath, clientPath)
		_, entry, resolveErr := s.resolveAbsolutePath(ctx, client, fullPath, false)
		switch {
		case resolveErr == nil && entry.IsDir():
			treatAsDir = true
		case resolveErr == nil:
			treatAsDir = false
		case errors.Is(resolveErr, errQuarkEntryNotFound):
			treatAsDir = false
		default:
			return resolveErr
		}
	}

	if treatAsDir {
		if fileName == "" {
			fileName = strings.TrimSpace(fileHeader.Filename)
		}
	} else {
		if fileName == "" {
			fileName = strings.Trim(strings.TrimSpace(path.Base(clientPath)), "/")
		}
		dirClientPath = s.normalizeClientPath(path.Dir(clientPath))
	}
	if fileName == "" {
		return errors.New("文件名不能为空")
	}

	fullDirPath := s.buildPath(config.RootPath, dirClientPath)
	_, dirEntry, err := s.resolveAbsolutePath(ctx, client, fullDirPath, true)
	if err != nil {
		return err
	}
	if !dirEntry.IsDir() {
		return errors.New("上传目标必须是目录")
	}

	return client.uploadMultipartFile(ctx, dirEntry.Fid, fileHeader, fileName)
}

func (s *QuarkFsService) resolveApplicationRoot(ctx context.Context, client *quarkClient, application string, create bool) (model.QuarkConfig, quarkDriveFile, string, error) {
	config, err := quarkConfigDao.GetByApplication(application)
	if err != nil {
		return model.QuarkConfig{}, quarkDriveFile{}, "", err
	}
	config.RootPath = s.normalizeConfiguredRootPath(config.RootPath)

	rootPath := config.RootPath
	if rootPath == "" {
		rootPath = "/"
	}
	if rootPath == "/" {
		return config, quarkDriveFile{Fid: "0", FileName: "/", Dir: true}, rootPath, nil
	}

	_, entry, err := s.resolveAbsolutePath(ctx, client, rootPath, create)
	if err != nil {
		return config, quarkDriveFile{}, rootPath, err
	}
	if !entry.IsDir() {
		return config, quarkDriveFile{}, rootPath, errors.New("应用根目录不是文件夹")
	}
	return config, entry, rootPath, nil
}

func (s *QuarkFsService) normalizeConfiguredRootPath(rawRootPath string) string {
	return normalizeConfiguredQuarkRootPath(rawRootPath)
}

func (s *QuarkFsService) resolveRelativePath(ctx context.Context, client *quarkClient, rootFid, rawPath string, createDirs bool) (string, quarkDriveFile, error) {
	clientPath := s.normalizeClientPath(rawPath)
	if clientPath == "/" {
		return "", quarkDriveFile{Fid: rootFid, FileName: "/", Dir: true}, nil
	}
	return s.traverseSegments(ctx, client, rootFid, s.splitPathSegments(clientPath), createDirs)
}

func (s *QuarkFsService) resolveAbsolutePath(ctx context.Context, client *quarkClient, fullPath string, createDirs bool) (string, quarkDriveFile, error) {
	normalized := s.normalizeHistoryPath(fullPath)
	if normalized == "" {
		return "", quarkDriveFile{}, errors.New("path 不能为空")
	}
	if normalized == "/" {
		return "", quarkDriveFile{Fid: "0", FileName: "/", Dir: true}, nil
	}
	return s.traverseSegments(ctx, client, "0", s.splitPathSegments(normalized), createDirs)
}

func (s *QuarkFsService) traverseSegments(ctx context.Context, client *quarkClient, startFid string, segments []string, createDirs bool) (string, quarkDriveFile, error) {
	current := quarkDriveFile{Fid: startFid, FileName: "/", Dir: true}
	parentFid := ""
	for idx, segment := range segments {
		parentFid = current.Fid
		child, err := client.findChildByName(ctx, current.Fid, segment)
		if err != nil {
			if errors.Is(err, errQuarkEntryNotFound) && createDirs {
				child, err = client.makeDir(ctx, current.Fid, segment)
				if err != nil {
					return "", quarkDriveFile{}, err
				}
				if strings.TrimSpace(child.Fid) == "" {
					child, err = client.findChildByName(ctx, current.Fid, segment)
					if err != nil {
						return "", quarkDriveFile{}, err
					}
				}
			} else {
				return "", quarkDriveFile{}, err
			}
		}
		child.FileName = child.Name()
		if idx < len(segments)-1 && !child.IsDir() {
			return "", quarkDriveFile{}, errors.New("path 不是目录")
		}
		current = child
	}
	return parentFid, current, nil
}

func (s *QuarkFsService) splitPathSegments(rawPath string) []string {
	trimmed := strings.Trim(strings.TrimSpace(strings.ReplaceAll(rawPath, "\\", "/")), "/")
	if trimmed == "" {
		return nil
	}
	parts := strings.Split(trimmed, "/")
	segments := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		segments = append(segments, part)
	}
	return segments
}

func (s *QuarkFsService) displayNameForRoot(rootPath string) string {
	rootPath = s.normalizeHistoryPath(rootPath)
	if rootPath == "" || rootPath == "/" {
		return "/"
	}
	name := strings.Trim(strings.TrimSpace(path.Base(rootPath)), "/")
	if name == "" {
		return "/"
	}
	return name
}

func (s *QuarkFsService) buildDeleteStagedName(name string) string {
	ext := path.Ext(name)
	base := strings.TrimSuffix(name, ext)
	if strings.TrimSpace(base) == "" {
		base = "deleted"
	}
	return fmt.Sprintf(".sz_del_%d_%s%s", time.Now().UnixNano(), base, ext)
}

func (s *QuarkFsService) buildPath(basePath, subPath string) string {
	base := strings.Trim(basePath, "/")
	sub := strings.Trim(subPath, "/")

	if base == "" && sub == "" {
		return "/"
	}
	if base == "" {
		return "/" + sub
	}
	if sub == "" {
		return "/" + base
	}
	return "/" + path.Join(base, sub)
}

func (s *QuarkFsService) normalizeClientPath(rawPath string) string {
	cleaned := strings.TrimSpace(strings.ReplaceAll(rawPath, "\\", "/"))
	if cleaned == "" {
		return "/"
	}
	if !strings.HasPrefix(cleaned, "/") {
		cleaned = "/" + cleaned
	}
	return path.Clean(cleaned)
}

func (s *QuarkFsService) normalizeAbsoluteSourcePath(rawPath string) string {
	normalized := s.normalizeHistoryPath(rawPath)
	if normalized == "" {
		return "/"
	}
	return s.normalizeConfiguredRootPath(normalized)
}
