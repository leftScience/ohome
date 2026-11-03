package conf

import (
	"ohome/model"

	"gorm.io/gorm"
)

func InitSchema(db *gorm.DB) error {
	if err := db.AutoMigrate(
		&model.Role{},
		&model.User{},
		&model.Config{},
		&model.DictType{},
		&model.DictData{},
		&model.File{},
		&model.QuarkConfig{},
		&model.QuarkAutoSaveTask{},
		&model.QuarkTransferTask{},
		&model.UserMediaHistory{},
		&model.AppMessage{},
	); err != nil {
		return err
	}

	return nil
}
