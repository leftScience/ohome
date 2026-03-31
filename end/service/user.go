package service

import (
	"errors"
	"fmt"
	"ohome/global"
	"ohome/model"
	"ohome/service/dto"
	"ohome/utils"
	"strings"

	"gorm.io/gorm"

	"github.com/spf13/viper"
)

type UserService struct {
	BaseService
}

func (m *UserService) Login(iUser dto.UserLoginDto) (model.User, string, string, error) {
	var errResult error
	var accessToken string
	var refreshToken string

	// 根据用户名去查询数据库存的用户信息
	mUser, err := userDao.GetUserByName(iUser.Name)

	// 比较密码是否正确
	isSamePwd := utils.CompareHashAndPassword(mUser.Password, iUser.Password)

	// 用户名或密码不正确
	if err != nil || !isSamePwd {
		errResult = errors.New("用户名或密码错误")
	} else if mUser.RoleID == 0 || mUser.Role.Code == "" {
		errResult = errors.New("用户角色不存在")
	} else { // 登录成功, 生成token

		accessToken, err = utils.GenerateAccessToken(mUser.ID, mUser.Name)
		refreshToken, err = utils.GenerateRefreshToken(mUser.ID, mUser.Name)

		if err != nil {
			errResult = errors.New(fmt.Sprintf("生成令牌失败：%s", err.Error()))
		}
	}

	return mUser, accessToken, refreshToken, errResult
}

func (m *UserService) IsRegistrationEnabled() bool {
	return viper.GetBool("config.allowUserRegistration")
}

func (m *UserService) Register(iUserRegisterDTO *dto.UserRegisterDTO) error {
	if !m.IsRegistrationEnabled() {
		return errors.New("当前服务端未开放注册")
	}

	name := strings.TrimSpace(iUserRegisterDTO.Name)
	if name == "" {
		return errors.New("用户名不能为空")
	}
	if strings.TrimSpace(iUserRegisterDTO.Password) == "" {
		return errors.New("密码不能为空")
	}
	exists, err := userDao.ExistsByName(name, 0)
	if err != nil {
		return err
	}
	if exists {
		return errors.New("用户名已存在")
	}

	role, err := m.resolveRoleByCode(model.RoleCodeUser, model.RoleCodeUser)
	if err != nil {
		return err
	}

	userAddDTO := &dto.UserAddDTO{
		Name:     name,
		Password: iUserRegisterDTO.Password,
		RoleID:   role.ID,
		RoleCode: role.Code,
		RealName: "",
		Avatar:   "",
	}

	return userDao.AddUser(userAddDTO)
}

func (m *UserService) AddUser(iUserAddDTO *dto.UserAddDTO) error {
	iUserAddDTO.Name = strings.TrimSpace(iUserAddDTO.Name)
	exists, err := userDao.ExistsByName(iUserAddDTO.Name, 0)
	if err != nil {
		return err
	}
	if exists {
		return errors.New("用户名已存在")
	}
	role, err := m.resolveRoleByCode(iUserAddDTO.RoleCode, model.RoleCodeUser)
	if err != nil {
		return err
	}
	iUserAddDTO.RoleID = role.ID
	iUserAddDTO.RoleCode = role.Code
	return userDao.AddUser(iUserAddDTO)
}

func (m *UserService) DeleteUserById(iCommonIDDTO *dto.CommonIDDTO, loginUser model.LoginUser) error {
	if iCommonIDDTO.ID == 0 {
		return errors.New("用户 ID 无效")
	}

	return global.DB.Transaction(func(tx *gorm.DB) error {
		target, err := userDao.GetUserByIdWithDB(tx, iCommonIDDTO.ID)
		if err != nil {
			return err
		}
		if target.ID == loginUser.ID {
			return errors.New("不能删除当前登录账号")
		}
		if target.Role.IsSuperAdmin() {
			total, err := userDao.CountByRoleCodeForUpdate(tx, model.RoleCodeSuperAdmin, 0)
			if err != nil {
				return err
			}
			if total <= 1 {
				return errors.New("至少需要保留一个超级管理员")
			}
		}
		if err := (&QuarkFsService{}).DeleteUserScopedRoots(target.ID); err != nil {
			return err
		}
		if err := quarkAutoSaveTaskDao.DeleteByOwnerUserIDWithDB(tx, target.ID); err != nil {
			return err
		}
		if err := quarkTransferTaskDao.DeleteByOwnerUserIDWithDB(tx, target.ID); err != nil {
			return err
		}
		if err := userMediaHistoryDao.DeleteByUserIDWithDB(tx, target.ID); err != nil {
			return err
		}
		return userDao.DeleteUserByIdWithDB(tx, iCommonIDDTO.ID)
	})
}

func (m *UserService) UpdateUser(iUserUpdateDTO *dto.UserUpdateDTO, loginUser model.LoginUser) error {
	if iUserUpdateDTO.ID == 0 {
		return errors.New("用户 ID 无效")
	}

	return global.DB.Transaction(func(tx *gorm.DB) error {
		currentUser, err := userDao.GetUserByIdWithDB(tx, iUserUpdateDTO.ID)
		if err != nil {
			return err
		}

		nextRole := currentUser.Role
		if iUserUpdateDTO.RoleCode != "" {
			role, err := m.resolveRoleByCode(iUserUpdateDTO.RoleCode, currentUser.Role.Code)
			if err != nil {
				return err
			}
			nextRole = role
		}

		if currentUser.Role.IsSuperAdmin() && !nextRole.IsSuperAdmin() {
			total, err := userDao.CountByRoleCodeForUpdate(tx, model.RoleCodeSuperAdmin, 0)
			if err != nil {
				return err
			}
			if total <= 1 {
				return errors.New("至少需要保留一个超级管理员")
			}
		}

		if name := strings.TrimSpace(iUserUpdateDTO.Name); name != "" {
			exists, err := userDao.ExistsByNameWithDB(tx, name, currentUser.ID)
			if err != nil {
				return err
			}
			if exists {
				return errors.New("用户名已存在")
			}
			iUserUpdateDTO.Name = name
		}

		iUserUpdateDTO.RealName = strings.TrimSpace(iUserUpdateDTO.RealName)
		iUserUpdateDTO.Avatar = strings.TrimSpace(iUserUpdateDTO.Avatar)
		iUserUpdateDTO.RoleID = nextRole.ID
		iUserUpdateDTO.ConvertToModel(&currentUser)
		currentUser.RoleID = nextRole.ID
		return userDao.UpdateUserByModelWithDB(tx, &currentUser)
	})
}

func (m *UserService) GetUserById(iCommonIDDTO *dto.CommonIDDTO) (model.User, error) {
	return userDao.GetUserById(iCommonIDDTO.ID)
}

func (m *UserService) GetUserList(iUserListDTO *dto.UserListDTO) ([]model.User, int64, error) {
	return userDao.GetUserList(iUserListDTO)
}

func (m *UserService) GetProfile(loginUser model.LoginUser) (model.User, error) {
	return userDao.GetUserById(loginUser.ID)
}

func (m *UserService) IsUsingDefaultPassword(loginUser model.LoginUser) (bool, error) {
	defaultPassword := strings.TrimSpace(viper.GetString("config.defaultPassword"))
	if defaultPassword == "" {
		return false, nil
	}

	mUser, err := userDao.GetUserById(loginUser.ID)
	if err != nil {
		return false, errors.New("用户不存在")
	}

	return utils.CompareHashAndPassword(mUser.Password, defaultPassword), nil
}

func (m *UserService) RefreshToken(iUserRefreshTokenDTO *dto.UserRefreshTokenDTO) (string, string, error) {
	var errResult error
	var accessToken string
	var refreshToken string
	var err error

	claims, err := utils.ParseRefreshToken(iUserRefreshTokenDTO.Token)
	if err != nil {
		errResult = errors.New("令牌已过期")
		return accessToken, refreshToken, errResult
	}
	accessToken, err = utils.GenerateAccessToken(claims.ID, claims.Name)
	if err != nil {
		errResult = errors.New("生成令牌失败")
		return accessToken, refreshToken, errResult
	}
	refreshToken, err = utils.GenerateRefreshToken(claims.ID, claims.Name)
	if err != nil {
		errResult = errors.New("生成令牌失败")
		return accessToken, refreshToken, errResult
	}

	return accessToken, refreshToken, errResult
}

func (m *UserService) ChangePassword(d *dto.UserChangePasswordDTO, loginUser model.LoginUser) error {

	// 根据用户ID查询数据库存的用户信息
	mUser, err := userDao.GetUserById(loginUser.ID)
	if err != nil {
		return errors.New("用户不存在")
	}

	// 比较密码是否正确
	isSamePwd := utils.CompareHashAndPassword(mUser.Password, d.OldPassword)

	if !isSamePwd {
		return errors.New("旧密码验证失败")
	}

	mUser.Password, _ = utils.Encrypt(d.NewPassword)

	err = userDao.UpdateUserByModel(&mUser)
	if err != nil {
		return errors.New("更新密码失败")
	}

	return nil
}

func (m *UserService) ResetPassword(id uint) error {
	mUser, err := userDao.GetUserById(id)
	if err != nil {
		return err
	}
	mUser.Password, _ = utils.Encrypt(viper.GetString("config.defaultPassword"))
	err = userDao.UpdateUserByModel(&mUser)

	if err != nil {
		return errors.New("更新密码失败")
	}

	return nil
}

func (m *UserService) resolveRoleByCode(roleCode string, defaultCode string) (model.Role, error) {
	if roleCode == "" {
		roleCode = defaultCode
	}
	role, err := roleDao.GetByCode(roleCode)
	if err != nil {
		return model.Role{}, errors.New("角色不存在")
	}
	return role, nil
}
