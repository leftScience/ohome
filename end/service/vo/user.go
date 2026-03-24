package vo

import "ohome/model"

type UserVO struct {
	ID        uint   `json:"id"`
	Name      string `json:"name"`
	RealName  string `json:"realName"`
	Avatar    string `json:"avatar"`
	RoleID    uint   `json:"roleId"`
	RoleCode  string `json:"roleCode"`
	RoleName  string `json:"roleName"`
	CreatedAt any    `json:"createdAt"`
	UpdatedAt any    `json:"updatedAt"`
}

type UserRegisterStatusVO struct {
	Enabled bool `json:"enabled"`
}

func BuildUserVO(user model.User) UserVO {
	return UserVO{
		ID:        user.ID,
		Name:      user.Name,
		RealName:  user.RealName,
		Avatar:    user.Avatar,
		RoleID:    user.RoleID,
		RoleCode:  user.Role.Code,
		RoleName:  user.Role.Name,
		CreatedAt: user.CreatedAt,
		UpdatedAt: user.UpdatedAt,
	}
}

func BuildUserVOList(users []model.User) []UserVO {
	result := make([]UserVO, 0, len(users))
	for _, user := range users {
		result = append(result, BuildUserVO(user))
	}
	return result
}
