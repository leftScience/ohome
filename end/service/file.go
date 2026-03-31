package service

import (
	"errors"
	"fmt"
	"net/url"
	"ohome/global/constants"
	"ohome/model"
	"ohome/service/dto"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type FileService struct {
	BaseService
}

const uploadApplication = "upload"

func (m *FileService) AddFile(ctx *gin.Context, fileUploadDTO dto.FileUploadDTO) (model.File, error) {
	var fileModel model.File

	if err := m.validateFileType(fileUploadDTO.Type); err != nil {
		return fileModel, err
	}

	file, err := ctx.FormFile("file")
	if err != nil {
		return fileModel, err
	}

	ts := time.Now().Unix()
	tsStr := strconv.FormatInt(ts, 10)
	ext := path.Ext(file.Filename)
	base := strings.TrimSuffix(file.Filename, ext)
	newFileName := base + "_" + tsStr + ext

	quarkFs := QuarkFsService{}
	if err := quarkFs.uploadFileToTarget(ctx.Request.Context(), uploadApplication, "/", file, newFileName, 0); err != nil {
		return fileModel, fmt.Errorf("上传文件失败: %w", err)
	}

	fileURL := "/api/v1/public/quarkFs/" + url.PathEscape(uploadApplication) + "/files/stream?path=" + url.QueryEscape("/"+newFileName)

	var loginUser = ctx.Keys[constants.LOGIN_USER].(model.LoginUser)

	var fileAddDTO dto.FileAddDTO
	fileAddDTO.Url = fileURL
	fileAddDTO.Type = fileUploadDTO.Type
	fileAddDTO.Description = fileUploadDTO.Description
	fileAddDTO.Name = file.Filename
	fileAddDTO.Size = file.Size
	fileAddDTO.UploaderId = loginUser.ID
	fileAddDTO.UploaderName = loginUser.Name

	fileModel, err = fileDao.AddFile(&fileAddDTO)

	return fileModel, err
}

func (m *FileService) GetFileById(iCommonIDDTO *dto.CommonIDDTO) (model.File, error) {
	return fileDao.GetFileById(iCommonIDDTO.ID)
}

func (m *FileService) GetFileList(fileListDTO *dto.FileListDTO) ([]model.File, int64, error) {
	return fileDao.GetFileList(fileListDTO)
}

func (m *FileService) UpdateFile(updateDTO *dto.FileUpdateDTO) error {
	if updateDTO.ID == 0 {
		return errors.New("文件ID无效")
	}

	if updateDTO.Type != nil {
		if err := m.validateFileType(*updateDTO.Type); err != nil {
			return err
		}
	}

	return fileDao.UpdateFile(updateDTO)
}

func (m *FileService) DeleteFile(iCommonIDDTO *dto.CommonIDDTO) error {
	if iCommonIDDTO.ID == 0 {
		return errors.New("文件ID无效")
	}

	return fileDao.DeleteFile(iCommonIDDTO.ID)
}

func (m *FileService) validateFileType(fileType string) error {
	if fileType == "" {
		return errors.New("文件类型不能为空")
	}

	isValid, err := dictDao.HasDictValue(constants.DICT_TYPE_FILE_TYPE, fileType)
	if err != nil {
		return err
	}
	if !isValid {
		return fmt.Errorf("文件类型[%s]未在字典中维护", fileType)
	}
	return nil
}
