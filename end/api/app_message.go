package api

import (
	"ohome/global"
	"ohome/service"
	"ohome/service/dto"
	"ohome/utils"

	"github.com/gin-gonic/gin"
)

type AppMessage struct {
	BaseApi
}

func NewAppMessageApi() AppMessage {
	return AppMessage{BaseApi: NewBaseApi()}
}

func (a *AppMessage) GetList(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	var listDTO dto.AppMessageListDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &listDTO}).GetErrors(); err != nil {
		return
	}
	messages, total, err := appMessageService.GetList(&listDTO, loginUser.ID)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	unreadCount, err := appMessageService.CountUnread(loginUser.ID, "")
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(gin.H{
		"records":     messages,
		"total":       total,
		"unreadCount": unreadCount,
	}, c)
}

func (a *AppMessage) MarkRead(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	var readDTO dto.AppMessageReadDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &readDTO}).GetErrors(); err != nil {
		return
	}
	if err := appMessageService.MarkRead(readDTO.ID, loginUser.ID); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.Ok(c)
}

func (a *AppMessage) MarkAllRead(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	if err := appMessageService.MarkAllRead(loginUser.ID); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.Ok(c)
}

func (a *AppMessage) Delete(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	var idDTO dto.CommonIDDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &idDTO}).GetErrors(); err != nil {
		return
	}
	if err := appMessageService.Delete(idDTO.ID, loginUser.ID); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.Ok(c)
}

func (a *AppMessage) Subscribe(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	if err := service.ServeAppMessageWS(c, loginUser.ID); err != nil && global.Logger != nil {
		global.Logger.Errorf("App Message WS Upgrade Error: user=%d err=%s", loginUser.ID, err.Error())
	}
}

func (a *AppMessage) SendSystemMessage(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	var dto dto.SendSystemMessageDTO
	if err := a.Request(RequestOptions{Ctx: c, DTO: &dto}).GetErrors(); err != nil {
		return
	}
	if err := appMessageService.SendSystemMessageToAll(dto.Title, dto.Content, loginUser.ID); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.Ok(c)
}
