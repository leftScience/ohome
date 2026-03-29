package dao

import (
	"errors"
	"ohome/global"
	"ohome/model"
	"ohome/service/dto"
)

type QuarkConfigDao struct {
	BaseDao
}

func (m *QuarkConfigDao) GetByApplication(application string) (model.QuarkConfig, error) {
	var count int64
	if err := global.DB.Model(&model.QuarkConfig{}).
		Where("application = ?", application).
		Count(&count).Error; err != nil {
		return model.QuarkConfig{}, err
	}
	if count > 1 {
		return model.QuarkConfig{}, errors.New("应用标识存在多条配置，请先清理重复数据")
	}

	var config model.QuarkConfig
	err := global.DB.Where("application = ?", application).First(&config).Error
	return config, err
}

func (m *QuarkConfigDao) GetList(listDTO *dto.QuarkConfigListDTO) ([]model.QuarkConfig, int64, error) {
	var configs []model.QuarkConfig
	var total int64

	query := global.DB.Model(&model.QuarkConfig{}).
		Order("updated_at desc")
	if listDTO.Application != "" {
		query = query.Where("application = ?", listDTO.Application)
	}
	query = query.Scopes(Paginate(listDTO.Paginate))

	query.Find(&configs).Offset(-1).Limit(-1).Count(&total)

	return configs, total, query.Error
}

func (m *QuarkConfigDao) Create(createDTO *dto.QuarkConfigCreateDTO) (model.QuarkConfig, error) {
	var config model.QuarkConfig
	createDTO.ConvertToModel(&config)

	var count int64
	if err := global.DB.Model(&model.QuarkConfig{}).
		Where("application = ?", config.Application).
		Count(&count).Error; err != nil {
		return model.QuarkConfig{}, err
	}
	if count > 0 {
		return model.QuarkConfig{}, errors.New("应用标识不能重复")
	}

	err := global.DB.Create(&config).Error

	return config, err
}

func (m *QuarkConfigDao) Update(updateDTO *dto.QuarkConfigUpdateDTO) error {
	var config model.QuarkConfig

	var count int64
	if err := global.DB.Model(&model.QuarkConfig{}).
		Where("application = ?", updateDTO.Application).
		Count(&count).Error; err != nil {
		return err
	}
	if count > 1 {
		return errors.New("应用标识存在多条配置，请先清理重复数据")
	}

	if err := global.DB.Where("application = ?", updateDTO.Application).First(&config).Error; err != nil {
		return err
	}

	updateDTO.ApplyToModel(&config)

	return global.DB.Save(&config).Error
}

func (m *QuarkConfigDao) Delete(application string) error {
	return global.DB.Where("application = ?", application).Delete(&model.QuarkConfig{}).Error
}
