package api

import (
	"ohome/model"
	"ohome/service"
	"testing"
)

func TestExclusiveOrdinaryUserCannotReadOrWriteGlobalQuarkCookies(t *testing.T) {
	user := model.LoginUser{ID: 12, Name: "u", RoleCode: model.RoleCodeUser}
	if canReadConfig(user, "quark_cookies") {
		t.Fatal("ordinary user must not read global quark_cookies via sys_config")
	}
	if canWriteConfig(user, "quark_cookies") {
		t.Fatal("ordinary user must not write/delete global quark_cookies via sys_config")
	}
	if canReadConfig(user, sensitiveConfigKeyQuarkTVRefreshToken) {
		t.Fatal("ordinary user must not read global TV refresh token")
	}
}

func TestSuperAdminCanReadGlobalQuarkCookies(t *testing.T) {
	admin := model.LoginUser{ID: 1, Name: "admin", RoleCode: model.RoleCodeSuperAdmin}
	if !canReadConfig(admin, "quark_cookies") {
		t.Fatal("super admin should read global quark_cookies")
	}
	if !canWriteConfig(admin, "quark_cookies") {
		t.Fatal("super admin should write global quark_cookies")
	}
}

func TestCanAccessQuarkCredentialAPITargets(t *testing.T) {
	service.SetQuarkAccountModeOverrideForTest(func(uint) string { return service.QuarkAccountModeExclusive })
	t.Cleanup(service.ClearQuarkAccountModeOverrideForTest)

	user := model.LoginUser{ID: 9, Name: "u", RoleCode: model.RoleCodeUser}
	admin := model.LoginUser{ID: 1, Name: "admin", RoleCode: model.RoleCodeSuperAdmin}

	if !canAccessQuarkCredentialAPI(user, service.QuarkCredentialTargetPersonal) {
		t.Fatal("exclusive user should access personal credentials")
	}
	if !canAccessQuarkCredentialAPI(user, service.QuarkCredentialTargetAuto) {
		t.Fatal("exclusive user should access auto credentials")
	}
	if canAccessQuarkCredentialAPI(user, service.QuarkCredentialTargetShared) {
		t.Fatal("exclusive ordinary user must not access shared credential target")
	}
	if !canAccessQuarkCredentialAPI(admin, service.QuarkCredentialTargetShared) {
		t.Fatal("super admin should access shared credential target")
	}
}
