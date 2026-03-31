package service

import (
	"ohome/model"
	"ohome/service/dto"
	"strings"
)

type QuarkConfigService struct {
	BaseService
}

func (s *QuarkConfigService) GetQuarkConfigByApplication(applicationDTO *dto.QuarkApplicationDTO, userID uint) (model.QuarkConfig, error) {
	config, err := quarkConfigDao.GetByApplication(strings.TrimSpace(applicationDTO.Application))
	if err != nil {
		return model.QuarkConfig{}, err
	}
	config.RootPath = normalizeQuarkConfigRootPathValue(resolveQuarkRootPathForUser(config.Application, config.RootPath, userID))
	return config, nil
}

func (s *QuarkConfigService) GetQuarkConfigList(listDTO *dto.QuarkConfigListDTO, userID uint) ([]model.QuarkConfig, int64, error) {
	listDTO.Application = strings.TrimSpace(listDTO.Application)
	configs, total, err := quarkConfigDao.GetList(listDTO)
	if err != nil {
		return nil, 0, err
	}
	for i := range configs {
		configs[i].RootPath = normalizeQuarkConfigRootPathValue(resolveQuarkRootPathForUser(configs[i].Application, configs[i].RootPath, userID))
	}
	return configs, total, nil
}

func (s *QuarkConfigService) CreateQuarkConfig(createDTO *dto.QuarkConfigCreateDTO) (model.QuarkConfig, error) {
	createDTO.Application = strings.TrimSpace(createDTO.Application)
	createDTO.RootPath = normalizeQuarkConfigRootPathValue(createDTO.RootPath)
	createDTO.Remark = strings.TrimSpace(createDTO.Remark)

	config, err := quarkConfigDao.Create(createDTO)
	if err != nil {
		return model.QuarkConfig{}, err
	}
	config.RootPath = normalizeQuarkConfigRootPathValue(config.RootPath)
	return config, nil
}

func (s *QuarkConfigService) UpdateQuarkConfig(updateDTO *dto.QuarkConfigUpdateDTO) error {
	updateDTO.Application = strings.TrimSpace(updateDTO.Application)
	if updateDTO.RootPath != nil {
		normalized := normalizeQuarkConfigRootPathValue(*updateDTO.RootPath)
		updateDTO.RootPath = &normalized
	}
	if updateDTO.Remark != nil {
		trimmed := strings.TrimSpace(*updateDTO.Remark)
		updateDTO.Remark = &trimmed
	}
	return quarkConfigDao.Update(updateDTO)
}

func (s *QuarkConfigService) DeleteQuarkConfig(applicationDTO *dto.QuarkApplicationDTO) error {
	return quarkConfigDao.Delete(strings.TrimSpace(applicationDTO.Application))
}
