package dto

import "ohome/model"

// ConfigListDTO 配置列表相关DTO
type ConfigListDTO struct {
	Name             string   `json:"name"`
	Key              string   `json:"key"`
	Keys             []string `json:"keys" form:"keys"`
	IsLock           string   `json:"isLock"`
	CredentialTarget string   `json:"credentialTarget"`
	ExcludeKeys      []string `json:"-" form:"-"`
	Paginate
}

type ConfigUpdateDTO struct {
	ID               uint   `json:"id" form:"id"`
	Name             string `json:"name" form:"name"`
	Key              string `json:"key" form:"key"`
	Value            string `json:"value" form:"value"`
	IsLock           string `json:"isLock" form:"isLock"`
	Remark           string `json:"remark" form:"remark"`
	CredentialTarget string `json:"credentialTarget"`
}

func (c *ConfigUpdateDTO) ConvertToModel(iConfig *model.Config) {
	iConfig.ID = c.ID
	iConfig.Name = c.Name
	iConfig.Key = c.Key
	iConfig.IsLock = c.IsLock
	iConfig.Remark = c.Remark
	iConfig.Value = c.Value
}
