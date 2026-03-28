package service

import (
	"errors"
	"fmt"
	"ohome/model"
	"ohome/service/dto"
	"ohome/utils"
	"strings"

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
		errResult = fmt.Errorf("error: %v", errors.New("Invalid UserName Or Password"))
	} else if mUser.RoleID == 0 || mUser.Role.Code == "" {
		errResult = errors.New("用户角色不存在")
	} else { // 登录成功, 生成token

		accessToken, err = utils.GenerateAccessToken(mUser.ID, mUser.Name)
		refreshToken, err = utils.GenerateRefreshToken(mUser.ID, mUser.Name)

		if err != nil {
			errResult = errors.New(fmt.Sprintf("Generate Token Error: %s", err.Error()))
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
	if userDao.CheckUserNameExist(name) {
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
	if userDao.CheckUserNameExist(iUserAddDTO.Name) {
		return errors.New("user Name Exist")
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
	target, err := userDao.GetUserById(iCommonIDDTO.ID)
	if err != nil {
		return err
	}
	if err := m.ensureCanDeleteUser(target, loginUser); err != nil {
		return err
	}
	return userDao.DeleteUserById(iCommonIDDTO.ID)
}

func (m *UserService) UpdateUser(iUserUpdateDTO *dto.UserUpdateDTO, loginUser model.LoginUser) error {
	if iUserUpdateDTO.ID == 0 {
		return errors.New("invalid User ID")
	}

	currentUser, err := userDao.GetUserById(iUserUpdateDTO.ID)
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

	if err := m.ensureCanDowngradeSuperAdmin(currentUser, nextRole); err != nil {
		return err
	}

	iUserUpdateDTO.RoleID = nextRole.ID
	return userDao.UpdateUser(iUserUpdateDTO)
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

func (m *UserService) RefreshToken(iUserRefreshTokenDTO *dto.UserRefreshTokenDTO) (string, string, error) {
	var errResult error
	var accessToken string
	var refreshToken string
	var err error

	claims, err := utils.ParseRefreshToken(iUserRefreshTokenDTO.Token)
	if err != nil {
		errResult = errors.New("token已过期")
		return accessToken, refreshToken, errResult
	}
	accessToken, err = utils.GenerateAccessToken(claims.ID, claims.Name)
	if err != nil {
		errResult = errors.New("Token Generate Error")
		return accessToken, refreshToken, errResult
	}
	refreshToken, err = utils.GenerateRefreshToken(claims.ID, claims.Name)
	if err != nil {
		errResult = errors.New("Token Generate Error")
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

func (m *UserService) ensureCanDeleteUser(target model.User, loginUser model.LoginUser) error {
	if target.ID != 0 && target.ID == loginUser.ID {
		return errors.New("不能删除当前登录账号")
	}
	if !target.Role.IsSuperAdmin() {
		return nil
	}
	total, err := userDao.CountByRoleCode(model.RoleCodeSuperAdmin, target.ID)
	if err != nil {
		return err
	}
	if total == 0 {
		return errors.New("至少需要保留一个超级管理员")
	}
	return nil
}

func (m *UserService) ensureCanDowngradeSuperAdmin(currentUser model.User, nextRole model.Role) error {
	if !currentUser.Role.IsSuperAdmin() || nextRole.IsSuperAdmin() {
		return nil
	}
	total, err := userDao.CountByRoleCode(model.RoleCodeSuperAdmin, currentUser.ID)
	if err != nil {
		return err
	}
	if total == 0 {
		return errors.New("至少需要保留一个超级管理员")
	}
	return nil
}
