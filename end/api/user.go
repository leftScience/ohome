package api

import (
	"fmt"
	"ohome/global/constants"
	"ohome/model"
	"ohome/service/dto"
	"ohome/service/vo"
	"ohome/utils"

	"github.com/gin-gonic/gin"
	"github.com/spf13/viper"
)

type User struct {
	BaseApi
}

func NewUserApi() User {
	return User{
		BaseApi: NewBaseApi(),
	}
}

// Login 用户登录
func (user *User) Login(context *gin.Context) {
	var userLoginDto dto.UserLoginDto
	if err := user.Request(RequestOptions{
		Ctx: context,
		DTO: &userLoginDto,
	}).GetErrors(); err != nil {
		return
	}

	//传入用户名和密码 然后根据这个查询出来用户 并生成当前用户的token
	iUser, accessToken, refreshToken, err := userService.Login(userLoginDto)

	if err != nil {
		fmt.Println(fmt.Errorf("%s", err))
		utils.FailWithMessage(err.Error(), context)
		return
	}
	utils.OkWithDetailed(gin.H{
		"accessToken":  accessToken,
		"refreshToken": refreshToken,
		"user":         vo.BuildUserVO(iUser),
	}, "登录成功", context)
}

func (user *User) Register(c *gin.Context) {
	var iUserRegisterDTO dto.UserRegisterDTO
	if err := user.Request(RequestOptions{
		Ctx: c,
		DTO: &iUserRegisterDTO,
	}).GetErrors(); err != nil {
		return
	}

	if err := userService.Register(&iUserRegisterDTO); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithMessage("注册成功", c)
}

func (user *User) GetRegisterStatus(c *gin.Context) {
	utils.OkWithData(vo.UserRegisterStatusVO{
		Enabled: userService.IsRegistrationEnabled(),
	}, c)
}

// AddUser 增加用户
func (user *User) AddUser(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	var iUserAddDTO dto.UserAddDTO
	err := user.Request(RequestOptions{
		Ctx: c,
		DTO: &iUserAddDTO,
	}).GetErrors()
	if err != nil {
		return
	}

	if iUserAddDTO.Password == "" {
		iUserAddDTO.Password = viper.GetString("config.defaultPassword")
	}

	err = userService.AddUser(&iUserAddDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.Ok(c)
}

// DeleteUserById 根据id删除用户
func (user *User) DeleteUserById(c *gin.Context) {
	loginUser, ok := requireSuperAdmin(c)
	if !ok {
		return
	}
	var iCommonIDDTO dto.CommonIDDTO
	if err := user.Request(RequestOptions{Ctx: c, DTO: &iCommonIDDTO}).GetErrors(); err != nil {
		return
	}

	err := userService.DeleteUserById(&iCommonIDDTO, loginUser)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithMessage("删除成功!", c)
}

// UpdateUser 修改用户
func (user *User) UpdateUser(c *gin.Context) {
	loginUser, ok := requireSuperAdmin(c)
	if !ok {
		return
	}
	var iUserUpdateDTO dto.UserUpdateDTO

	if err := user.Request(RequestOptions{Ctx: c, DTO: &iUserUpdateDTO}).GetErrors(); err != nil {
		return
	}

	err := userService.UpdateUser(&iUserUpdateDTO, loginUser)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.Ok(c)
}

// GetUserById 根据id进行查询
func (user *User) GetUserById(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	var iCommonIDDTO dto.CommonIDDTO
	if err := user.Request(RequestOptions{Ctx: c, DTO: &iCommonIDDTO}).GetErrors(); err != nil {
		return
	}

	iUser, err := userService.GetUserById(&iCommonIDDTO)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(vo.BuildUserVO(iUser), c)
}

// GetUserList 获取用户列表（分页）
func (user *User) GetUserList(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	var iUserListDTO dto.UserListDTO
	if err := user.Request(RequestOptions{Ctx: c, DTO: &iUserListDTO}).GetErrors(); err != nil {
		return
	}

	giUserList, nTotal, err := userService.GetUserList(&iUserListDTO)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(gin.H{
		"records": vo.BuildUserVOList(giUserList),
		"total":   nTotal,
	}, c)
}

func (user *User) GetProfile(c *gin.Context) {
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	profile, err := userService.GetProfile(loginUser)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(vo.BuildUserVO(profile), c)
}

func (user *User) RefreshToken(c *gin.Context) {
	var iUserRefreshTokenDTO dto.UserRefreshTokenDTO
	if err := user.Request(RequestOptions{Ctx: c, DTO: &iUserRefreshTokenDTO}).GetErrors(); err != nil {
		return
	}
	accessToken, refreshToken, err := userService.RefreshToken(&iUserRefreshTokenDTO)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.OkWithData(gin.H{
		"accessToken":  accessToken,
		"refreshToken": refreshToken,
	}, c)
}

func (user *User) UpdateAvatar(c *gin.Context) {
	var fileUploadDTO dto.FileUploadDTO
	fileUploadDTO.Type = "userAvatar"

	addFile, err := fileService.AddFile(c, fileUploadDTO)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	var iUserUpdateDTO dto.UserUpdateDTO
	var modelUser model.User
	loginUser, err := getLoginUser(c)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	modelUser, err = userService.GetProfile(loginUser)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	modelUser.Avatar = addFile.Url

	iUserUpdateDTO.ID = modelUser.ID
	iUserUpdateDTO.Name = modelUser.Name
	iUserUpdateDTO.Avatar = modelUser.Avatar
	iUserUpdateDTO.RealName = modelUser.RealName
	iUserUpdateDTO.RoleCode = modelUser.Role.Code

	err = userService.UpdateUser(&iUserUpdateDTO, loginUser)

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}

	utils.Ok(c)
}

func (user *User) ChangePassword(c *gin.Context) {
	var iUserChangePasswordDTO = dto.UserChangePasswordDTO{}
	if err := user.Request(RequestOptions{Ctx: c, DTO: &iUserChangePasswordDTO}).GetErrors(); err != nil {
		return
	}
	var loginUser = c.Keys[constants.LOGIN_USER].(model.LoginUser)
	err := userService.ChangePassword(&iUserChangePasswordDTO, loginUser)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.Ok(c)
}

func (user *User) ResetPassword(c *gin.Context) {
	if _, ok := requireSuperAdmin(c); !ok {
		return
	}
	var iCommonIDDTO dto.CommonIDDTO
	if err := user.Request(RequestOptions{Ctx: c, DTO: &iCommonIDDTO}).GetErrors(); err != nil {
		return
	}
	err := userService.ResetPassword(iCommonIDDTO.ID)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.Ok(c)
}
