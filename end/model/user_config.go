package model

type UserConfig struct {
	CommonModel
	UserID uint   `json:"userId" gorm:"not null;uniqueIndex:uk_sys_user_config_user_key;index:idx_sys_user_config_user_id"`
	Key    string `json:"key" gorm:"size:100;not null;uniqueIndex:uk_sys_user_config_user_key"`
	Value  string `json:"value" gorm:"type:text;not null"`
	Remark string `json:"remark" gorm:"size:255"`
}
