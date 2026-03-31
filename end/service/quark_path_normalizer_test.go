package service

import "testing"

func TestBuildQuarkUserScopedRootPath(t *testing.T) {
	tests := []struct {
		name   string
		raw    string
		userID uint
		want   string
	}{
		{name: "configured root", raw: "WP/VEDIO", userID: 12, want: "/WP/VEDIO/12"},
		{name: "root slash", raw: "/", userID: 7, want: "/7"},
		{name: "blank root", raw: "", userID: 5, want: "/5"},
		{name: "raw root without user", raw: "WP/VEDIO", userID: 0, want: "/WP/VEDIO"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := buildQuarkUserScopedRootPath(tt.raw, tt.userID); got != tt.want {
				t.Fatalf("buildQuarkUserScopedRootPath(%q, %d) = %q, want %q", tt.raw, tt.userID, got, tt.want)
			}
		})
	}
}

func TestResolveQuarkRootPathForUserUploadIsShared(t *testing.T) {
	got := resolveQuarkRootPathForUser("upload", "WP/UPLOAD", 9)
	if got != "/WP/UPLOAD" {
		t.Fatalf("resolveQuarkRootPathForUser(upload) = %q, want %q", got, "/WP/UPLOAD")
	}
}
