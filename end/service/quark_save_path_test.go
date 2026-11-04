package service

import "testing"

func TestBuildQuarkSavePathExclusiveAlignsBrowseRoot(t *testing.T) {
	quarkAccountModeOverride = func(uint) string { return QuarkAccountModeExclusive }
	t.Cleanup(func() { quarkAccountModeOverride = nil })

	got := buildQuarkSavePath("WP/VEDIO", 12, "tv")
	if got != "/WP/VEDIO/12" {
		t.Fatalf("exclusive save path = %q, want /WP/VEDIO/12", got)
	}
}

func TestBuildQuarkSavePathDoesNotDoubleScope(t *testing.T) {
	quarkAccountModeOverride = func(uint) string { return QuarkAccountModeExclusive }
	t.Cleanup(func() { quarkAccountModeOverride = nil })

	got := buildQuarkSavePath("WP/VEDIO/12", 12, "tv")
	if got != "/WP/VEDIO/12" {
		t.Fatalf("already scoped path = %q, want /WP/VEDIO/12", got)
	}
}

func TestBuildQuarkSavePathSharedUnchanged(t *testing.T) {
	quarkAccountModeOverride = func(uint) string { return QuarkAccountModeShared }
	t.Cleanup(func() { quarkAccountModeOverride = nil })

	got := buildQuarkSavePath("WP/VEDIO", 12, "tv")
	if got != "/WP/VEDIO" {
		t.Fatalf("shared save path = %q, want /WP/VEDIO", got)
	}
}

func TestBuildQuarkSavePathOwnerZeroSkipsExclusiveScope(t *testing.T) {
	quarkAccountModeOverride = func(uint) string { return QuarkAccountModeExclusive }
	t.Cleanup(func() { quarkAccountModeOverride = nil })

	// OwnerUserID=0 旧任务：即使系统独享也不追加用户目录，避免写进未知隔离树。
	got := buildQuarkSavePath("WP/VEDIO", 0, "tv")
	if got != "/WP/VEDIO" {
		t.Fatalf("owner0 save path = %q, want /WP/VEDIO", got)
	}
}

func TestBuildQuarkSavePathUploadStaysShared(t *testing.T) {
	quarkAccountModeOverride = func(uint) string { return QuarkAccountModeExclusive }
	t.Cleanup(func() { quarkAccountModeOverride = nil })

	got := buildQuarkSavePath("WP/UPLOAD", 12, "upload")
	if got != "/WP/UPLOAD" {
		t.Fatalf("upload save path = %q, want /WP/UPLOAD", got)
	}
}

func TestResolveQuarkCredentialTargetSharedIgnoresExclusiveMode(t *testing.T) {
	quarkAccountModeOverride = func(uint) string { return QuarkAccountModeExclusive }
	t.Cleanup(func() { quarkAccountModeOverride = nil })

	usePersonal, err := resolveQuarkCredentialUsePersonal(1, QuarkCredentialTargetShared)
	if err != nil {
		t.Fatal(err)
	}
	if usePersonal {
		t.Fatal("shared target must write global credentials even if admin preferExclusive")
	}

	usePersonal, err = resolveQuarkCredentialUsePersonal(9, QuarkCredentialTargetPersonal)
	if err != nil {
		t.Fatal(err)
	}
	if !usePersonal {
		t.Fatal("personal target must write user_config")
	}
}

func TestStripTrailingQuarkUserScopeSegment(t *testing.T) {
	if got := stripTrailingQuarkUserScopeSegment("WP/VEDIO/12", 12); got != "WP/VEDIO" {
		t.Fatalf("strip = %q, want WP/VEDIO", got)
	}
	if got := stripTrailingQuarkUserScopeSegment("WP/VEDIO/13", 12); got != "WP/VEDIO/13" {
		t.Fatalf("non-matching suffix should keep path, got %q", got)
	}
}
