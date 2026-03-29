package service

import (
	"testing"

	"github.com/spf13/viper"

	"ohome/model"
	"ohome/service/dto"
)

func TestIsUsingDefaultPassword(t *testing.T) {
	restore := setupPhase2TestDB(t)
	defer restore()

	role := seedRole(t, "普通用户", model.RoleCodeUser)
	user := seedUser(t, "default-user", role.ID)

	previousDefaultPassword := viper.Get("config.defaultPassword")
	viper.Set("config.defaultPassword", "123456")
	defer viper.Set("config.defaultPassword", previousDefaultPassword)

	service := &UserService{}
	usingDefaultPassword, err := service.IsUsingDefaultPassword(model.LoginUser{
		ID:       user.ID,
		Name:     user.Name,
		RoleID:   user.RoleID,
		RoleCode: role.Code,
	})
	if err != nil {
		t.Fatalf("IsUsingDefaultPassword() error = %v", err)
	}
	if !usingDefaultPassword {
		t.Fatal("IsUsingDefaultPassword() = false, want true")
	}
}

func TestIsUsingDefaultPasswordReturnsFalseAfterPasswordChanged(t *testing.T) {
	restore := setupPhase2TestDB(t)
	defer restore()

	role := seedRole(t, "普通用户", model.RoleCodeUser)
	user := seedUser(t, "custom-user", role.ID)

	previousDefaultPassword := viper.Get("config.defaultPassword")
	viper.Set("config.defaultPassword", "123456")
	defer viper.Set("config.defaultPassword", previousDefaultPassword)

	service := &UserService{}
	if err := service.ChangePassword(&dto.UserChangePasswordDTO{
		OldPassword: "123456",
		NewPassword: "654321",
	}, model.LoginUser{
		ID:       user.ID,
		Name:     user.Name,
		RoleID:   user.RoleID,
		RoleCode: role.Code,
	}); err != nil {
		t.Fatalf("ChangePassword() error = %v", err)
	}

	usingDefaultPassword, err := service.IsUsingDefaultPassword(model.LoginUser{
		ID:       user.ID,
		Name:     user.Name,
		RoleID:   user.RoleID,
		RoleCode: role.Code,
	})
	if err != nil {
		t.Fatalf("IsUsingDefaultPassword() error = %v", err)
	}
	if usingDefaultPassword {
		t.Fatal("IsUsingDefaultPassword() = true, want false")
	}
}
