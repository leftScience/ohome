package cmd

import (
	"ohome/conf"
	"ohome/discovery"
	"ohome/global"
	"ohome/router"
	"ohome/service"
	"ohome/task"
)

func Start() {
	conf.InitConfig()
	global.Logger = conf.InitLogger()

	discoveryManager, err := discovery.Initialize()
	if err != nil {
		panic(err.Error())
	}
	discovery.Default = discoveryManager

	discoveryPublisher, err := discovery.NewPublisher(discoveryManager)
	if err != nil {
		if global.Logger != nil {
			global.Logger.Warnf("Start mDNS publisher failed: %s", err.Error())
		}
	} else {
		defer discoveryPublisher.Shutdown()
	}

	//初始化db
	db, err := conf.InitDB()
	if err != nil {
		panic(err.Error())
	}
	global.DB = db

	var quarkTransferTaskService service.QuarkTransferTaskService
	if err := quarkTransferTaskService.RecoverInterruptedTasks(); err != nil && global.Logger != nil {
		global.Logger.Errorf("Recover Quark Transfer Task Error: %s", err.Error())
	}
	service.EnsureQuarkTransferTaskExecutor()

	task.StartDoubanSyncScheduler()
	task.StartQuarkAutoSaveScheduler()
	task.StartDropsReminderScheduler()

	router.InitRouter()
}
