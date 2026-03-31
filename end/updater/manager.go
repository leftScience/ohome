package updater

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"ohome/buildinfo"
	"ohome/global"
)

const restartTimeout = 10 * time.Second

type ProcessController interface {
	RestartCurrentServer(timeout time.Duration) error
	StopCurrentServer(timeout time.Duration) error
}

type Manager struct {
	store      *Store
	controller ProcessController
	mu         sync.Mutex
}

type applyBinaryResult struct {
	targetVersion  string
	releasePath    string
	autoRolledBack bool
}

func NewManager(controller ProcessController) *Manager {
	return &Manager{store: NewStore(), controller: controller}
}

func (m *Manager) Info() (InfoResponse, error) {
	mode := DetectDeployMode()
	currentVersion := m.detectCurrentVersion(mode)
	state, err := m.store.LoadState()
	if err != nil {
		return InfoResponse{}, err
	}
	var currentTask *Task
	if state.CurrentTask != nil {
		copyTask := *state.CurrentTask
		copyTask.CanRollback = false
		currentTask = &copyTask
	}
	return InfoResponse{
		DeployMode:       mode,
		CurrentVersion:   currentVersion,
		UpdaterReachable: true,
		CurrentTask:      currentTask,
	}, nil
}

func (m *Manager) Check(req CheckRequest) (CheckResponse, error) {
	mode := DetectDeployMode()
	manifest, err := FetchManifestWithFallback(ManifestURLs())
	if err != nil {
		return CheckResponse{}, err
	}
	currentVersion := m.detectCurrentVersion(mode)
	available := CompareVersions(strings.TrimSpace(manifest.Version), currentVersion) > 0
	return CheckResponse{
		Available:      available,
		CurrentVersion: currentVersion,
		LatestVersion:  strings.TrimSpace(manifest.Version),
		ReleaseNotes:   strings.TrimSpace(manifest.ReleaseNotes),
		DeployMode:     mode,
	}, nil
}

func (m *Manager) Apply(req ApplyRequest) (ApplyResponse, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	state, err := m.store.LoadState()
	if err != nil {
		return ApplyResponse{}, err
	}
	if state.CurrentTask != nil && !state.CurrentTask.Terminal() {
		return ApplyResponse{}, fmt.Errorf("已有更新任务正在执行")
	}

	mode := DetectDeployMode()
	currentVersion := m.detectCurrentVersion(mode)
	task := &Task{
		ID:             fmt.Sprintf("upd-%d", time.Now().UnixNano()),
		Status:         StatusQueued,
		Step:           "已排队",
		Progress:       0,
		StartedAt:      time.Now(),
		CurrentVersion: currentVersion,
		DeployMode:     mode,
		Channel:        strings.TrimSpace(req.Channel),
	}
	state.ActiveTaskID = task.ID
	state.LastTaskID = task.ID
	state.CurrentTask = task
	state.DeployMode = mode
	state.CurrentVersion = currentVersion
	state.RuntimeVersion = buildinfo.CleanRuntimeVersion()
	if err := m.store.SaveTask(task); err != nil {
		return ApplyResponse{}, err
	}
	if err := m.store.SaveState(state); err != nil {
		return ApplyResponse{}, err
	}
	go m.runApplyTask(task, req)
	return ApplyResponse{TaskID: task.ID, Status: task.Status}, nil
}

func (m *Manager) Rollback(req RollbackRequest) (ApplyResponse, error) {
	return ApplyResponse{}, fmt.Errorf("当前版本暂不支持手动回滚")
}

func (m *Manager) Task(taskID string) (*Task, error) {
	return m.store.LoadTask(taskID)
}

func (m *Manager) runApplyTask(task *Task, req ApplyRequest) {
	manifest, err := FetchManifestWithFallback(ManifestURLs())
	if err != nil {
		m.failTask(task, err)
		return
	}

	targetVersion := strings.TrimSpace(req.TargetVersion)
	if targetVersion == "" {
		targetVersion = strings.TrimSpace(manifest.Version)
	} else if CompareVersions(strings.TrimSpace(manifest.Version), targetVersion) != 0 {
		m.failTask(task, fmt.Errorf("当前清单仅支持更新到 %s", strings.TrimSpace(manifest.Version)))
		return
	}

	task.TargetVersion = targetVersion
	m.advanceTask(task, StatusChecking, 8, "检查更新清单")
	if CompareVersions(targetVersion, task.CurrentVersion) <= 0 {
		m.failTask(task, fmt.Errorf("当前已是最新版本"))
		return
	}

	state, _ := m.store.LoadState()
	previousVersion := task.CurrentVersion
	previousReleasePath := strings.TrimSpace(state.CurrentReleasePath)
	result, err := m.applyBinary(task, manifest, previousReleasePath)
	if err != nil {
		m.failTask(task, err)
		return
	}

	state, _ = m.store.LoadState()
	state.ActiveTaskID = ""
	state.CurrentTask = task
	state.DeployMode = DetectDeployMode()
	state.RuntimeVersion = buildinfo.CleanRuntimeVersion()
	if result.autoRolledBack {
		state.CurrentVersion = previousVersion
		state.CurrentReleasePath = previousReleasePath
		_ = m.store.SaveState(state)
		return
	}

	m.completeTask(task, StatusSuccess, 100, "更新完成", false)
	state.CurrentVersion = result.targetVersion
	state.PreviousVersion = previousVersion
	state.CurrentReleasePath = result.releasePath
	state.PreviousReleasePath = previousReleasePath
	_ = m.store.SaveState(state)
}

func (m *Manager) runRollbackTask(task *Task) {
	state, err := m.store.LoadState()
	if err != nil {
		m.failTask(task, err)
		return
	}

	currentVersion := m.detectCurrentVersion(DetectDeployMode())
	currentReleasePath := strings.TrimSpace(state.CurrentReleasePath)
	previousReleasePath := strings.TrimSpace(state.PreviousReleasePath)
	previousVersion := strings.TrimSpace(state.PreviousVersion)
	if previousReleasePath == "" || previousVersion == "" {
		m.failTask(task, fmt.Errorf("缺少回滚版本信息"))
		return
	}

	if err := m.rollbackBinary(task, currentReleasePath, previousReleasePath); err != nil {
		m.failTask(task, err)
		return
	}

	m.completeTask(task, StatusRolledBack, 100, "已回滚到上一个稳定版本", strings.TrimSpace(currentReleasePath) != "")
	state.ActiveTaskID = ""
	state.CurrentTask = task
	state.CurrentVersion = previousVersion
	state.PreviousVersion = currentVersion
	state.CurrentReleasePath = previousReleasePath
	state.PreviousReleasePath = currentReleasePath
	state.RuntimeVersion = buildinfo.CleanRuntimeVersion()
	_ = m.store.SaveState(state)
}

func (m *Manager) applyBinary(task *Task, manifest ServerManifest, previousReleasePath string) (applyBinaryResult, error) {
	if m.controller == nil {
		return applyBinaryResult{}, fmt.Errorf("启动器进程控制器未初始化")
	}
	if err := validateRuntimeCompatibility(manifest); err != nil {
		return applyBinaryResult{}, err
	}

	artifactKey, artifact, err := selectArtifact(manifest)
	if err != nil {
		return applyBinaryResult{}, err
	}

	m.advanceTask(task, StatusDownloading, 20, "下载服务端二进制")
	archivePath, err := downloadArtifact(m.store.TempDir(), task.ID, artifact.URL)
	if err != nil {
		return applyBinaryResult{}, err
	}
	defer os.Remove(archivePath)

	if err := verifySHA256File(archivePath, artifact.SHA256); err != nil {
		return applyBinaryResult{}, err
	}

	releasePath := filepath.Join(m.store.ReleasesDir(), task.TargetVersion)
	if err := extractServerArchive(archivePath, releasePath, artifact.Format); err != nil {
		return applyBinaryResult{}, err
	}

	m.advanceTask(task, StatusInstalling, 55, "重启服务端进程")
	if err := setCurrentReleaseLink(m.store.CurrentReleaseLink(), releasePath); err != nil {
		return applyBinaryResult{}, err
	}
	if err := m.controller.RestartCurrentServer(restartTimeout); err != nil {
		if strings.TrimSpace(previousReleasePath) != "" {
			if rollbackErr := rollbackCurrentRelease(m.store.CurrentReleaseLink(), previousReleasePath); rollbackErr == nil {
				_ = m.controller.RestartCurrentServer(restartTimeout)
			}
		}
		return applyBinaryResult{}, err
	}

	m.advanceTask(task, StatusHealthCheck, 90, "等待服务恢复")
	if err := waitForHealth(HealthURLForMode(DetectDeployMode()), 60*time.Second); err != nil {
		if strings.TrimSpace(previousReleasePath) != "" {
			if rollbackErr := rollbackCurrentRelease(m.store.CurrentReleaseLink(), previousReleasePath); rollbackErr == nil {
				if restartErr := m.controller.RestartCurrentServer(restartTimeout); restartErr == nil {
					if waitErr := waitForHealth(HealthURLForMode(DetectDeployMode()), 40*time.Second); waitErr == nil {
						m.completeTask(task, StatusRolledBack, 100, "新版本启动失败，已自动回滚", true)
						if global.Logger != nil {
							global.Logger.Warnf("binary update auto rolled back artifact=%s version=%s", artifactKey, task.TargetVersion)
						}
						return applyBinaryResult{
							targetVersion:  task.CurrentVersion,
							releasePath:    previousReleasePath,
							autoRolledBack: true,
						}, nil
					}
				}
			}
		}
		return applyBinaryResult{}, err
	}

	if global.Logger != nil {
		global.Logger.Infof("updated runtime artifact=%s version=%s release=%s", artifactKey, task.TargetVersion, releasePath)
	}
	return applyBinaryResult{
		targetVersion: task.TargetVersion,
		releasePath:   releasePath,
	}, nil
}

func (m *Manager) rollbackBinary(task *Task, currentReleasePath string, previousReleasePath string) error {
	if m.controller == nil {
		return fmt.Errorf("启动器进程控制器未初始化")
	}

	m.advanceTask(task, StatusInstalling, 50, "切换回滚版本")
	if err := setCurrentReleaseLink(m.store.CurrentReleaseLink(), previousReleasePath); err != nil {
		return err
	}
	if err := m.controller.RestartCurrentServer(restartTimeout); err != nil {
		if strings.TrimSpace(currentReleasePath) != "" {
			if rollbackErr := rollbackCurrentRelease(m.store.CurrentReleaseLink(), currentReleasePath); rollbackErr == nil {
				_ = m.controller.RestartCurrentServer(restartTimeout)
			}
		}
		return err
	}

	m.advanceTask(task, StatusHealthCheck, 90, "等待服务恢复")
	if err := waitForHealth(HealthURLForMode(DetectDeployMode()), 60*time.Second); err != nil {
		if strings.TrimSpace(currentReleasePath) != "" {
			if rollbackErr := rollbackCurrentRelease(m.store.CurrentReleaseLink(), currentReleasePath); rollbackErr == nil {
				_ = m.controller.RestartCurrentServer(restartTimeout)
			}
		}
		return err
	}
	return nil
}

func (m *Manager) detectCurrentVersion(mode DeployMode) string {
	if version, err := detectVersionFromHealth(HealthURLForMode(mode)); err == nil && strings.TrimSpace(version) != "" {
		return strings.TrimSpace(version)
	}
	if state, err := m.store.LoadState(); err == nil && strings.TrimSpace(state.CurrentVersion) != "" {
		return strings.TrimSpace(state.CurrentVersion)
	}
	return buildinfo.CleanVersion()
}

func detectVersionFromHealth(url string) (string, error) {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("健康检查状态异常：%s", resp.Status)
	}
	var envelope struct {
		Code int `json:"code"`
		Data struct {
			Version string `json:"version"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&envelope); err != nil {
		return "", err
	}
	return envelope.Data.Version, nil
}

func (m *Manager) advanceTask(task *Task, status TaskStatus, progress int, step string) {
	task.Status = status
	task.Progress = progress
	task.Step = step
	task.Message = step
	task.CanRollback = false
	_ = m.store.SaveTask(task)
	state, _ := m.store.LoadState()
	state.ActiveTaskID = task.ID
	state.LastTaskID = task.ID
	state.CurrentTask = task
	state.RuntimeVersion = buildinfo.CleanRuntimeVersion()
	state.DeployMode = DetectDeployMode()
	_ = m.store.SaveState(state)
}

func (m *Manager) completeTask(task *Task, status TaskStatus, progress int, message string, canRollback bool) {
	now := time.Now()
	task.Status = status
	task.Progress = progress
	task.Step = message
	task.Message = message
	task.CanRollback = canRollback
	task.FinishedAt = &now
	_ = m.store.SaveTask(task)
}

func (m *Manager) failTask(task *Task, err error) {
	if global.Logger != nil {
		global.Logger.Errorf("update task failed: %v", err)
	}
	now := time.Now()
	task.Status = StatusFailed
	task.Step = "更新失败"
	task.Message = err.Error()
	task.FinishedAt = &now
	task.CanRollback = false
	_ = m.store.SaveTask(task)
	state, _ := m.store.LoadState()
	state.ActiveTaskID = ""
	state.LastTaskID = task.ID
	state.CurrentTask = task
	state.RuntimeVersion = buildinfo.CleanRuntimeVersion()
	state.DeployMode = DetectDeployMode()
	_ = m.store.SaveState(state)
}

func selectArtifact(manifest ServerManifest) (string, BinaryArtifact, error) {
	return selectArtifactForPlatform(manifest, runtime.GOOS, runtime.GOARCH)
}

func selectArtifactForPlatform(manifest ServerManifest, goos string, goarch string) (string, BinaryArtifact, error) {
	artifactKey, err := ArtifactKeyForPlatform(goos, goarch)
	if err != nil {
		return "", BinaryArtifact{}, err
	}
	artifact, ok := manifest.Artifacts[artifactKey]
	if !ok {
		return "", BinaryArtifact{}, fmt.Errorf("更新清单缺少 %s 对应的二进制产物", artifactKey)
	}
	if strings.TrimSpace(artifact.URL) == "" || strings.TrimSpace(artifact.SHA256) == "" {
		return "", BinaryArtifact{}, fmt.Errorf("%s 对应的二进制产物信息不完整", artifactKey)
	}
	artifact.Format = normalizeArtifactFormat(artifact.Format, artifact.URL)
	return artifactKey, artifact, nil
}

func validateRuntimeCompatibility(manifest ServerManifest) error {
	minRuntimeVersion := strings.TrimSpace(manifest.MinRuntimeVersion)
	if minRuntimeVersion == "" {
		return nil
	}
	currentRuntimeVersion := buildinfo.CleanRuntimeVersion()
	if CompareVersions(currentRuntimeVersion, minRuntimeVersion) < 0 {
		return fmt.Errorf("当前运行时版本 %s 低于最低要求 %s，请先手动升级到最新独立运行包", currentRuntimeVersion, minRuntimeVersion)
	}
	return nil
}
