package dto

import "ohome/model"

type UserLoginDto struct {
	Name     string `json:"name" binding:"required" massage:"用户名校验错误" required_err:"用户名不能为空"`
	Password string `json:"password" binding:"required" massage:"密码校验错误" required_err:"密码不能为空"`
}

type UserRegisterDTO struct {
	Name     string `json:"name" binding:"required" massage:"用户名校验错误" required_err:"用户名不能为空"`
	Password string `json:"password" binding:"required" massage:"密码校验错误" required_err:"密码不能为空"`
}

// UserAddDTO 添加用户相关
type UserAddDTO struct {
	ID       uint
	RoleID   uint
	Name     string `json:"name" form:"name" binding:"required" message:"用户名不能为空"`
	RealName string `json:"realName" form:"realName"`
	Avatar   string `json:"avatar"`
	RoleCode string `json:"roleCode" form:"roleCode"`
	//Password string `json:"password,omitempty" form:"password" binding:"required" message:"密码不能为空"`
	Password string `json:"password,omitempty" form:"password"`
}

func (m *UserAddDTO) ConvertToModel(iUser *model.User) {
	iUser.Name = m.Name
	iUser.RealName = m.RealName
	iUser.Avatar = m.Avatar
	iUser.Password = m.Password
	iUser.RoleID = m.RoleID
}

// UserUpdateDTO 更新用户相关DTO
type UserUpdateDTO struct {
	ID       uint `json:"id" form:"id" uri:"id"`
	RoleID   uint
	Name     string `json:"name" form:"name"`
	RealName string `json:"realName" form:"realName"`
	Avatar   string `json:"avatar" form:"avatar"`
	RoleCode string `json:"roleCode" form:"roleCode"`
}

func (m UserUpdateDTO) ConvertToModel(iUser *model.User) {
	iUser.ID = m.ID
	iUser.Name = m.Name
	iUser.RealName = m.RealName
	iUser.Avatar = m.Avatar
	iUser.RoleID = m.RoleID
}

// UserListDTO 用户列表相关DTO
type UserListDTO struct {
	Name string `json:"name"`
	Paginate
}

type UserRefreshTokenDTO struct {
	Token string `json:"token" form:"token" uri:"token"`
}

type UserChangePasswordDTO struct {
	OldPassword string `json:"oldPassword" form:"oldPassword"`
	NewPassword string `json:"newPassword" form:"newPassword"`
}
