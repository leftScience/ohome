package service

import (
	"ohome/model"
	"testing"
)

func TestResolveHistoryPathWithUserScopedRoot(t *testing.T) {
	svc := QuarkFsService{}

	if got := svc.resolveHistoryPath("/WP/VEDIO/12", "/WP/VEDIO/12"); got != "/" {
		t.Fatalf("resolveHistoryPath(root) = %q, want /", got)
	}
	if got := svc.resolveHistoryPath("/WP/VEDIO/12/电影/第1集.mp4", "/WP/VEDIO/12"); got != "/电影/第1集.mp4" {
		t.Fatalf("resolveHistoryPath(descendant) = %q", got)
	}
}

func TestIsApplicationRootPathWithConfigsUsesUserScopedRoot(t *testing.T) {
	svc := QuarkFsService{}
	configs := []model.QuarkConfig{
		{Application: "tv", RootPath: "WP/VEDIO"},
		{Application: "music", RootPath: "WP/MUSIC"},
	}

	if !svc.isApplicationRootPathWithConfigs("/WP/VEDIO/12", configs, 12) {
		t.Fatal("expected /WP/VEDIO/12 to be treated as current user's application root")
	}
	if svc.isApplicationRootPathWithConfigs("/WP/VEDIO/13", configs, 12) {
		t.Fatal("did not expect another user's root folder to be treated as current user's application root")
	}
}

func TestResolveSourceApplicationAndHistoryPathWithConfigs(t *testing.T) {
	svc := QuarkFsService{}
	configs := []model.QuarkConfig{
		{Application: "tv", RootPath: "WP/VEDIO"},
		{Application: "music", RootPath: "WP/MUSIC"},
	}

	application, historyPath, err := svc.resolveSourceApplicationAndHistoryPathWithConfigs(
		"/WP/VEDIO/12/电影/第1集.mp4",
		"music",
		"WP/MUSIC",
		12,
		configs,
	)
	if err != nil {
		t.Fatalf("resolveSourceApplicationAndHistoryPathWithConfigs error = %v", err)
	}
	if application != "tv" {
		t.Fatalf("application = %q, want %q", application, "tv")
	}
	if historyPath != "/电影/第1集.mp4" {
		t.Fatalf("historyPath = %q, want %q", historyPath, "/电影/第1集.mp4")
	}
}
