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

// 共享模式下 personal 目标没有任何运行时读取方，必须在权限层就拒绝，
// 否则会写入「配置页显示已配置、实际永远不生效」的死数据。
func TestSharedModeRejectsPersonalCredentialTarget(t *testing.T) {
	service.SetQuarkAccountModeOverrideForTest(func(uint) string { return service.QuarkAccountModeShared })
	t.Cleanup(service.ClearQuarkAccountModeOverrideForTest)

	user := model.LoginUser{ID: 9, Name: "u", RoleCode: model.RoleCodeUser}
	admin := model.LoginUser{ID: 1, Name: "admin", RoleCode: model.RoleCodeSuperAdmin}

	if canAccessQuarkCredentialAPI(user, service.QuarkCredentialTargetPersonal) {
		t.Fatal("shared mode must not expose personal credential target")
	}
	if canAccessQuarkCredentialAPI(admin, service.QuarkCredentialTargetPersonal) {
		t.Fatal("shared mode must not expose personal target even for super admin")
	}
	if !canAccessQuarkCredentialAPI(admin, service.QuarkCredentialTargetShared) {
		t.Fatal("super admin should still manage shared credentials in shared mode")
	}
	if !canAccessQuarkCredentialAPI(admin, service.QuarkCredentialTargetAuto) {
		t.Fatal("super admin should access auto target in shared mode")
	}
	if canAccessQuarkCredentialAPI(user, service.QuarkCredentialTargetAuto) {
		t.Fatal("shared-mode ordinary user must not manage credentials")
	}
}
