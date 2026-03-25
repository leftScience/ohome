package api

import (
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	"ohome/global/constants"
	"ohome/model"
	"ohome/service"
	"ohome/service/dto"
	"ohome/utils"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type QuarkFs struct {
	BaseApi
}

func NewQuarkFsApi() QuarkFs {
	return QuarkFs{
		BaseApi: NewBaseApi(),
	}
}

func (a *QuarkFs) GetQuarkFileList(c *gin.Context) {
	var pathDTO dto.QuarkPathDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &pathDTO}).GetErrors(); err != nil {
		return
	}

	files, err := quarkFsService.ListFiles(&pathDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(files, c)
}

func (a *QuarkFs) GetQuarkFileMetadata(c *gin.Context) {
	var pathDTO dto.QuarkPathDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &pathDTO}).GetErrors(); err != nil {
		return
	}

	meta, err := quarkFsService.GetFileMetadata(&pathDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(meta, c)
}

func (a *QuarkFs) StreamQuarkFile(c *gin.Context) {
	var pathDTO dto.QuarkPathDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &pathDTO}).GetErrors(); err != nil {
		return
	}

	isCast := c.Query("cast") == "true"
	rangeHeader := c.GetHeader("Range")
	if c.Request.Method == http.MethodHead {
		meta, err := quarkFsService.DescribeFile(&pathDTO)
		if err != nil {
			utils.FailWithMessage(err.Error(), c)
			return
		}
		responseMeta, err := service.BuildQuarkProxyResponseMeta(meta.Size, rangeHeader)
		if err != nil {
			c.Status(http.StatusRequestedRangeNotSatisfiable)
			return
		}
		a.writeProxyHeaders(c, meta, responseMeta, isCast, "")
		c.Status(responseMeta.StatusCode)
		return
	}

	result, meta, err := quarkFsService.StreamFile(c.Request.Context(), &pathDTO, rangeHeader)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	defer result.Body.Close()

	a.writeStreamResponse(c, result, meta, isCast)
}

func (a *QuarkFs) writeStreamResponse(
	c *gin.Context,
	result *service.QuarkStreamResult,
	meta service.QuarkProxyMeta,
	cast bool,
) {
	responseMeta := service.QuarkProxyResponseMeta{
		ContentLength: result.ContentLength,
		StatusCode:    result.StatusCode,
		ContentRange:  result.ContentRange,
	}
	a.writeProxyHeaders(c, meta, responseMeta, cast, result.ContentType)
	c.Status(result.StatusCode)
	c.Writer.Flush() // 立即发送响应头，让播放器尽快获取文件信息
	_, _ = io.Copy(c.Writer, result.Body)
}

func (a *QuarkFs) writeProxyHeaders(
	c *gin.Context,
	meta service.QuarkProxyMeta,
	responseMeta service.QuarkProxyResponseMeta,
	cast bool,
	contentType string,
) {
	if contentType == "" {
		contentType = mime.TypeByExtension(path.Ext(meta.Filename))
	}
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	c.Header("Content-Type", contentType)
	c.Header("Accept-Ranges", "bytes")
	if cast {
		c.Header("transferMode.dlna.org", "Streaming")
		c.Header("contentFeatures.dlna.org", buildDLNAContentFeatures(contentType))
	}

	if responseMeta.ContentRange != "" {
		c.Header("Content-Range", responseMeta.ContentRange)
	}
	if responseMeta.ContentLength > 0 {
		c.Header("Content-Length", strconv.FormatInt(responseMeta.ContentLength, 10))
	}
	if etag := buildQuarkProxyETag(meta); etag != "" {
		c.Header("ETag", etag)
	}
	if meta.UpdatedAt > 0 {
		c.Header("Last-Modified", time.Unix(meta.UpdatedAt, 0).UTC().Format(http.TimeFormat))
	}

	if header := mime.FormatMediaType("inline", map[string]string{"filename": meta.Filename}); header != "" {
		c.Header("Content-Disposition", header)
	} else if meta.Filename != "" {
		c.Header("Content-Disposition", `inline; filename="`+meta.Filename+`"`)
	}
}

func buildDLNAContentFeatures(contentType string) string {
	contentType = strings.TrimSpace(contentType)
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	return contentType + ":DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000"
}

func buildQuarkProxyETag(meta service.QuarkProxyMeta) string {
	if meta.Filename == "" && meta.Size <= 0 && meta.UpdatedAt <= 0 {
		return ""
	}
	return fmt.Sprintf(`"%x-%x"`, meta.UpdatedAt, meta.Size)
}

func (a *QuarkFs) RenameQuarkFile(c *gin.Context) {
	var renameDTO dto.QuarkRenameDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &renameDTO}).GetErrors(); err != nil {
		return
	}
	userID, err := a.getLoginUserID(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	if err := quarkFsService.RenameFile(&renameDTO, userID); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithMessage("重命名成功", c)
}

func (a *QuarkFs) DeleteQuarkFile(c *gin.Context) {
	var pathDTO dto.QuarkPathDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &pathDTO}).GetErrors(); err != nil {
		return
	}
	userID, err := a.getLoginUserID(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	if err := quarkFsService.DeleteFile(&pathDTO, userID); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithMessage("删除成功", c)
}

func (a *QuarkFs) UploadQuarkFile(c *gin.Context) {
	var pathDTO dto.QuarkPathDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &pathDTO}).GetErrors(); err != nil {
		return
	}

	fileHeader, err := c.FormFile("file")
	if err != nil {
		utils.FailWithMessage("文件不能为空", c)
		return
	}

	if err := quarkFsService.UploadFile(&pathDTO, fileHeader); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithMessage("上传成功", c)
}

func (a *QuarkFs) MoveQuarkFile(c *gin.Context) {
	var pathDTO dto.QuarkPathDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &pathDTO}).GetErrors(); err != nil {
		return
	}
	userID, err := a.getLoginUserID(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	if err := quarkFsService.MoveFile(&pathDTO, userID); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithMessage("移动成功", c)
}

func (a *QuarkFs) getLoginUserID(c *gin.Context) (uint, error) {
	value, ok := c.Get(constants.LOGIN_USER)
	if !ok {
		return 0, errors.New("用户信息不存在")
	}
	loginUser, ok := value.(model.LoginUser)
	if !ok || loginUser.ID == 0 {
		return 0, errors.New("用户信息不存在")
	}
	return loginUser.ID, nil
}
