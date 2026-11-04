package service

import "ohome/dao"

var (
	userDao              dao.UserDao
	roleDao              dao.RoleDao
	configDao            dao.ConfigDao
	dictDao              dao.DictDao
	fileDao              dao.FileDao
	quarkConfigDao       dao.QuarkConfigDao
	userMediaHistoryDao  dao.UserMediaHistoryDao
	doubanDao            dao.DoubanDao
	quarkAutoSaveTaskDao dao.QuarkAutoSaveTaskDao
	quarkTransferTaskDao dao.QuarkTransferTaskDao
	userConfigDao        dao.UserConfigDao
)
