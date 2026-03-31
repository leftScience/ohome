package updater

import (
	"slices"
	"strings"
	"time"
)

type DeployMode string

const (
	DeployModeBinary DeployMode = "binary"
	DeployModeDocker DeployMode = "docker"
)

type TaskStatus string

const (
	StatusQueued      TaskStatus = "queued"
	StatusChecking    TaskStatus = "checking"
	StatusDownloading TaskStatus = "downloading"
	StatusInstalling  TaskStatus = "installing"
	StatusHealthCheck TaskStatus = "health_check"
	StatusSuccess     TaskStatus = "success"
	StatusFailed      TaskStatus = "failed"
	StatusRolledBack  TaskStatus = "rolled_back"
)

type DockerRelease struct {
	Image string `json:"image"`
	Tag   string `json:"tag"`
}

type BinaryArtifact struct {
	URL    string   `json:"url"`
	URLs   []string `json:"urls,omitempty"`
	SHA256 string   `json:"sha256"`
	Format string   `json:"format,omitempty"`
}

func (a BinaryArtifact) CandidateURLs() []string {
	result := make([]string, 0, len(a.URLs)+1)
	appendURL := func(raw string) {
		trimmed := strings.TrimSpace(raw)
		if trimmed == "" || slices.Contains(result, trimmed) {
			return
		}
		result = append(result, trimmed)
	}
	appendURL(a.URL)
	for _, raw := range a.URLs {
		appendURL(raw)
	}
	return result
}

func (a BinaryArtifact) PrimaryURL() string {
	urls := a.CandidateURLs()
	if len(urls) == 0 {
		return ""
	}
	return urls[0]
}

type ServerManifest struct {
	Channel                   string                    `json:"channel"`
	Version                   string                    `json:"version"`
	ReleaseNotes              string                    `json:"releaseNotes"`
	PublishedAt               string                    `json:"publishedAt"`
	MinRuntimeVersion         string                    `json:"minRuntimeVersion,omitempty"`
	RecommendedRuntimeVersion string                    `json:"recommendedRuntimeVersion,omitempty"`
	Artifacts                 map[string]BinaryArtifact `json:"artifacts,omitempty"`
	Docker                    DockerRelease             `json:"docker,omitempty"`
}

type Task struct {
	ID              string     `json:"id"`
	Status          TaskStatus `json:"status"`
	Step            string     `json:"step"`
	Progress        int        `json:"progress"`
	Message         string     `json:"message"`
	StartedAt       time.Time  `json:"startedAt"`
	FinishedAt      *time.Time `json:"finishedAt,omitempty"`
	TargetVersion   string     `json:"targetVersion"`
	CurrentVersion  string     `json:"currentVersion"`
	PreviousVersion string     `json:"previousVersion,omitempty"`
	DeployMode      DeployMode `json:"deployMode"`
	CanRollback     bool       `json:"canRollback"`
	Channel         string     `json:"channel,omitempty"`
}

type State struct {
	ActiveTaskID        string     `json:"activeTaskId,omitempty"`
	LastTaskID          string     `json:"lastTaskId,omitempty"`
	CurrentVersion      string     `json:"currentVersion,omitempty"`
	PreviousVersion     string     `json:"previousVersion,omitempty"`
	CurrentReleasePath  string     `json:"currentReleasePath,omitempty"`
	PreviousReleasePath string     `json:"previousReleasePath,omitempty"`
	RuntimeVersion      string     `json:"runtimeVersion,omitempty"`
	CurrentTask         *Task      `json:"currentTask,omitempty"`
	DeployMode          DeployMode `json:"deployMode,omitempty"`
	UpdatedAt           time.Time  `json:"updatedAt"`
}

type InfoResponse struct {
	DeployMode       DeployMode `json:"deployMode"`
	CurrentVersion   string     `json:"currentVersion"`
	UpdaterReachable bool       `json:"updaterReachable"`
	CurrentTask      *Task      `json:"currentTask,omitempty"`
}

type CheckRequest struct {
	Channel string `json:"channel"`
}

type CheckResponse struct {
	Available      bool       `json:"available"`
	CurrentVersion string     `json:"currentVersion"`
	LatestVersion  string     `json:"latestVersion"`
	ReleaseNotes   string     `json:"releaseNotes"`
	DeployMode     DeployMode `json:"deployMode"`
}

type ApplyRequest struct {
	Channel       string `json:"channel"`
	TargetVersion string `json:"targetVersion,omitempty"`
}

type ApplyResponse struct {
	TaskID string     `json:"taskId"`
	Status TaskStatus `json:"status"`
}

type RollbackRequest struct {
	TaskID string `json:"taskId,omitempty"`
}

func (t Task) Terminal() bool {
	switch t.Status {
	case StatusSuccess, StatusFailed, StatusRolledBack:
		return true
	default:
		return false
	}
}
