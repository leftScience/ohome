package service

import (
	"context"
	"errors"
	"ohome/service/dto"
	"strings"
	"time"
)

const quarkSharePreviewTimeout = 30 * time.Second

// SharePreview 预览夸克分享链接内的文件列表（支持逐级进入子目录）。
func (s *QuarkAutoSaveTaskService) SharePreview(previewDTO *dto.QuarkSharePreviewDTO, ownerUserID uint) (*dto.QuarkSharePreviewResultDTO, error) {
	if previewDTO == nil {
		return nil, errors.New("分享链接为空")
	}

	ctx, cancel := context.WithTimeout(context.Background(), quarkSharePreviewTimeout)
	defer cancel()

	cookie, err := loadPrimaryQuarkCookieForUser(ownerUserID)
	if err != nil {
		return nil, err
	}

	client := newQuarkClient(cookie)
	client.cookieScopeExclusive = quarkCredentialUsePersonal(ownerUserID)
	if err := client.initAccount(ctx); err != nil {
		return nil, wrapQuarkSharePreviewError(err)
	}

	pwdID, passcode, defaultPdirFid, err := extractShareParams(previewDTO.ShareURL)
	if err != nil {
		return nil, err
	}
	if manualPasscode := strings.TrimSpace(previewDTO.Passcode); manualPasscode != "" {
		passcode = manualPasscode
	}

	pdirFid := strings.TrimSpace(previewDTO.PdirFid)
	if pdirFid == "" {
		pdirFid = defaultPdirFid
	}
	if pdirFid == "" {
		pdirFid = "0"
	}

	stoken, err := client.getStoken(ctx, pwdID, passcode)
	if err != nil {
		return nil, wrapQuarkSharePreviewError(err)
	}

	shareFiles, err := client.getShareDetailAll(ctx, pwdID, stoken, pdirFid)
	if err != nil {
		return nil, wrapQuarkSharePreviewError(err)
	}

	files := make([]dto.QuarkSharePreviewFileDTO, 0, len(shareFiles))
	for _, sf := range shareFiles {
		files = append(files, dto.QuarkSharePreviewFileDTO{
			Fid:       strings.TrimSpace(sf.Fid),
			FileName:  strings.TrimSpace(sf.FileName),
			IsDir:     sf.Dir,
			Size:      sf.Size,
			UpdatedAt: sf.UpdatedAt,
		})
	}

	return &dto.QuarkSharePreviewResultDTO{Files: files, PdirFid: pdirFid}, nil
}

func wrapQuarkSharePreviewError(err error) error {
	if errors.Is(err, context.DeadlineExceeded) {
		return errors.New("预览超时，请稍后重试")
	}
	return err
}
