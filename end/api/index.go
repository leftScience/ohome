package api

import (
	"ohome/service"
)

var (
	userService              service.UserService
	configService            service.ConfigService
	dictService              service.DictService
	fileService              service.FileService
	quarkConfigService       service.QuarkConfigService
	quarkFsService           service.QuarkFsService
	quarkTVLoginService      service.QuarkTVLoginService
	userMediaHistoryService  service.UserMediaHistoryService
	doubanService            service.DoubanService
	pansouService            service.PansouService
	quarkAutoSaveTaskService service.QuarkAutoSaveTaskService
	quarkTransferTaskService service.QuarkTransferTaskService
	appMessageService        service.AppMessageService
)
