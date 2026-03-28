package updater

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"ohome/buildinfo"
	"ohome/global"
)

type Manager struct {
	store *Store
	mu    sync.Mutex
}

func NewManager() *Manager {
	return &Manager{store: NewStore()}
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
		copyTask.CanRollback = m.canRollback(&copyTask, state)
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
	channel := strings.TrimSpace(req.Channel)
	if channel == "" {
		channel = DefaultChannel()
	}
	manifest, err := FetchManifest(ManifestURL())
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
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.store.LoadState()
	if err != nil {
		return ApplyResponse{}, err
	}
	if state.CurrentTask != nil && !state.CurrentTask.Terminal() {
		return ApplyResponse{}, fmt.Errorf("已有更新任务正在执行")
	}
	if strings.TrimSpace(state.PreviousVersion) == "" {
		return ApplyResponse{}, fmt.Errorf("没有可回滚的上一个稳定版本")
	}
	mode := DetectDeployMode()
	currentVersion := m.detectCurrentVersion(mode)
	task := &Task{
		ID:              fmt.Sprintf("rollback-%d", time.Now().UnixNano()),
		Status:          StatusQueued,
		Step:            "已排队",
		Progress:        0,
		StartedAt:       time.Now(),
		CurrentVersion:  currentVersion,
		TargetVersion:   state.PreviousVersion,
		PreviousVersion: state.CurrentVersion,
		DeployMode:      mode,
	}
	state.ActiveTaskID = task.ID
	state.LastTaskID = task.ID
	state.CurrentTask = task
	if err := m.store.SaveTask(task); err != nil {
		return ApplyResponse{}, err
	}
	if err := m.store.SaveState(state); err != nil {
		return ApplyResponse{}, err
	}
	go m.runRollbackTask(task)
	return ApplyResponse{TaskID: task.ID, Status: task.Status}, nil
}

func (m *Manager) Task(taskID string) (*Task, error) {
	return m.store.LoadTask(taskID)
}

func (m *Manager) runApplyTask(task *Task, req ApplyRequest) {
	mode := task.DeployMode
	channel := strings.TrimSpace(req.Channel)
	if channel == "" {
		channel = DefaultChannel()
	}
	manifest, err := FetchManifest(ManifestURL())
	if err != nil {
		m.failTask(task, err)
		return
	}
	targetVersion := strings.TrimSpace(req.TargetVersion)
	if targetVersion == "" {
		targetVersion = strings.TrimSpace(manifest.Version)
	}
	task.TargetVersion = targetVersion
	m.advanceTask(task, StatusChecking, 8, "检查更新清单")
	if CompareVersions(targetVersion, task.CurrentVersion) <= 0 {
		m.failTask(task, fmt.Errorf("当前已是最新版本"))
		return
	}
	state, _ := m.store.LoadState()
	previousVersion := task.CurrentVersion
	previousImage := state.CurrentImage
	if mode == DeployModeDocker {
		if err := m.applyDocker(task, manifest, targetVersion, previousVersion, previousImage); err != nil {
			m.failTask(task, err)
			return
		}
	} else {
		if err := m.applyPortable(task, manifest, targetVersion, previousVersion); err != nil {
			m.failTask(task, err)
			return
		}
	}
	if task.Status == StatusRolledBack {
		state, _ = m.store.LoadState()
		state.ActiveTaskID = ""
		state.CurrentTask = task
		state.CurrentVersion = previousVersion
		state.PreviousVersion = ""
		if mode == DeployModeDocker {
			state.CurrentImage = previousImage
			state.PreviousImage = ""
		}
		_ = m.store.SaveState(state)
		return
	}
	m.completeTask(task, StatusSuccess, 100, "更新完成", false)
	state, _ = m.store.LoadState()
	state.ActiveTaskID = ""
	state.CurrentTask = task
	state.CurrentVersion = targetVersion
	state.PreviousVersion = previousVersion
	state.DeployMode = mode
	if mode == DeployModeDocker {
		state.PreviousImage = previousImage
		state.CurrentImage = manifest.Docker.Image + ":" + manifest.Docker.Tag
	}
	_ = m.store.SaveState(state)
}

func (m *Manager) runRollbackTask(task *Task) {
	state, err := m.store.LoadState()
	if err != nil {
		m.failTask(task, err)
		return
	}
	mode := DetectDeployMode()
	currentVersion := m.detectCurrentVersion(mode)
	if mode == DeployModeDocker {
		if strings.TrimSpace(state.PreviousImage) == "" {
			m.failTask(task, fmt.Errorf("缺少回滚镜像信息"))
			return
		}
		if err := m.rollbackDocker(task, state.PreviousImage, state.PreviousVersion); err != nil {
			m.failTask(task, err)
			return
		}
	} else {
		if err := m.rollbackPortable(task, state.PreviousVersion); err != nil {
			m.failTask(task, err)
			return
		}
	}
	m.completeTask(task, StatusRolledBack, 100, "已回滚到上一个稳定版本", true)
	state.ActiveTaskID = ""
	state.CurrentTask = task
	state.CurrentVersion = state.PreviousVersion
	state.PreviousVersion = currentVersion
	if mode == DeployModeDocker {
		state.CurrentImage, state.PreviousImage = state.PreviousImage, state.CurrentImage
	}
	_ = m.store.SaveState(state)
}

func (m *Manager) applyPortable(task *Task, manifest ServerManifest, targetVersion string, previousVersion string) error {
	artifact, ok := manifest.Portable[CurrentPortableArtifactKey()]
	if !ok || strings.TrimSpace(artifact.URL) == "" {
		return fmt.Errorf("当前平台缺少可用便携包")
	}
	m.advanceTask(task, StatusDownloading, 20, "下载便携包")
	archivePath := filepath.Join(PortableDownloadDir(), fmt.Sprintf("ohome-%s.zip", targetVersion))
	if err := DownloadFile(artifact.URL, archivePath); err != nil {
		return err
	}
	m.advanceTask(task, StatusVerifying, 35, "校验安装包")
	if checksum := strings.TrimSpace(artifact.SHA256); checksum != "" {
		actual, err := ComputeSHA256(archivePath)
		if err != nil {
			return err
		}
		if !strings.EqualFold(actual, checksum) {
			return fmt.Errorf("安装包校验失败")
		}
	}
	m.advanceTask(task, StatusStopping, 45, "停止当前服务")
	if err := stopPortableServer(); err != nil {
		return err
	}
	m.advanceTask(task, StatusInstalling, 60, "解压新版本")
	versionDir := filepath.Join(PortableVersionsDir(), targetVersion)
	if err := os.RemoveAll(versionDir); err != nil {
		return err
	}
	if err := unzipArchive(archivePath, versionDir); err != nil {
		return err
	}
	m.advanceTask(task, StatusStarting, 75, "切换并启动新版本")
	if err := writeCurrentPortableVersion(targetVersion); err != nil {
		return err
	}
	if err := startPortableServerDetached(targetVersion); err != nil {
		_ = writeCurrentPortableVersion(previousVersion)
		return err
	}
	m.advanceTask(task, StatusHealthCheck, 90, "等待服务恢复")
	if err := waitForHealth(HealthURLForMode(DeployModePortable), 40*time.Second); err != nil {
		_ = stopPortableServer()
		_ = writeCurrentPortableVersion(previousVersion)
		_ = startPortableServerDetached(previousVersion)
		if rollbackErr := waitForHealth(HealthURLForMode(DeployModePortable), 30*time.Second); rollbackErr == nil {
			m.completeTask(task, StatusRolledBack, 100, "新版本启动失败，已自动回滚", true)
			state, _ := m.store.LoadState()
			state.ActiveTaskID = ""
			state.CurrentTask = task
			_ = m.store.SaveState(state)
			return nil
		}
		return err
	}
	return nil
}

func (m *Manager) rollbackPortable(task *Task, targetVersion string) error {
	m.advanceTask(task, StatusStopping, 40, "停止当前服务")
	if err := stopPortableServer(); err != nil {
		return err
	}
	m.advanceTask(task, StatusStarting, 70, "启动回滚版本")
	if err := writeCurrentPortableVersion(targetVersion); err != nil {
		return err
	}
	if err := startPortableServerDetached(targetVersion); err != nil {
		return err
	}
	m.advanceTask(task, StatusHealthCheck, 90, "等待服务恢复")
	return waitForHealth(HealthURLForMode(DeployModePortable), 40*time.Second)
}

func (m *Manager) applyDocker(task *Task, manifest ServerManifest, targetVersion string, previousVersion string, previousImage string) error {
	dockerImage := strings.TrimSpace(manifest.Docker.Image)
	dockerTag := strings.TrimSpace(manifest.Docker.Tag)
	if dockerImage == "" || dockerTag == "" {
		return fmt.Errorf("更新清单缺少 docker 镜像信息")
	}
	m.advanceTask(task, StatusDownloading, 20, "拉取 Docker 镜像")
	targetImage := dockerImage + ":" + dockerTag
	if err := writeComposeImage(targetImage); err != nil {
		return err
	}
	if err := m.runComposeCommand("pull", DockerServiceName()); err != nil {
		_ = writeComposeImage(previousImage)
		return err
	}
	m.advanceTask(task, StatusInstalling, 55, "重启 Docker 服务")
	if err := m.runComposeCommand("up", "-d", DockerServiceName()); err != nil {
		_ = writeComposeImage(previousImage)
		return err
	}
	m.advanceTask(task, StatusHealthCheck, 90, "等待服务恢复")
	if err := waitForHealth(HealthURLForMode(DeployModeDocker), 60*time.Second); err != nil {
		if strings.TrimSpace(previousImage) != "" {
			_ = writeComposeImage(previousImage)
			if rollbackErr := m.runComposeCommand("up", "-d", DockerServiceName()); rollbackErr == nil {
				if waitErr := waitForHealth(HealthURLForMode(DeployModeDocker), 40*time.Second); waitErr == nil {
					m.completeTask(task, StatusRolledBack, 100, "新镜像启动失败，已自动回滚", true)
					state, _ := m.store.LoadState()
					state.ActiveTaskID = ""
					state.CurrentTask = task
					_ = m.store.SaveState(state)
					return nil
				}
			}
		}
		return err
	}
	return nil
}

func (m *Manager) rollbackDocker(task *Task, image string, version string) error {
	m.advanceTask(task, StatusInstalling, 50, "切换回滚镜像")
	if err := writeComposeImage(image); err != nil {
		return err
	}
	if err := m.runComposeCommand("up", "-d", DockerServiceName()); err != nil {
		return err
	}
	task.TargetVersion = version
	m.advanceTask(task, StatusHealthCheck, 90, "等待服务恢复")
	return waitForHealth(HealthURLForMode(DeployModeDocker), 60*time.Second)
}

func (m *Manager) runComposeCommand(args ...string) error {
	fullArgs := []string{"compose", "-f", DockerComposeFile()}
	fullArgs = append(fullArgs, args...)
	cmd := exec.Command("docker", fullArgs...)
	cmd.Dir = DockerComposeProjectDir()
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("docker %s 失败: %v\n%s", strings.Join(fullArgs, " "), err, string(output))
	}
	return nil
}

func writeComposeImage(image string) error {
	if strings.TrimSpace(image) == "" {
		return nil
	}
	path := DockerEnvFile()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	var output bytes.Buffer
	lines := []string{}
	if payload, err := os.ReadFile(path); err == nil {
		scanner := bufio.NewScanner(bytes.NewReader(payload))
		for scanner.Scan() {
			lines = append(lines, scanner.Text())
		}
		if err := scanner.Err(); err != nil {
			return err
		}
	}
	updated := false
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, DockerImageEnvName()+"=") {
			output.WriteString(DockerImageEnvName() + "=" + image + "\n")
			updated = true
			continue
		}
		output.WriteString(line + "\n")
	}
	if !updated {
		output.WriteString(DockerImageEnvName() + "=" + image + "\n")
	}
	return os.WriteFile(path, output.Bytes(), 0o644)
}

func (m *Manager) detectCurrentVersion(mode DeployMode) string {
	if version, err := detectVersionFromHealth(HealthURLForMode(mode)); err == nil && strings.TrimSpace(version) != "" {
		return strings.TrimSpace(version)
	}
	if mode == DeployModePortable {
		if version, err := readCurrentPortableVersion(); err == nil && strings.TrimSpace(version) != "" {
			return strings.TrimSpace(version)
		}
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
		return "", fmt.Errorf("health status: %s", resp.Status)
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
	_ = m.store.SaveState(state)
}

func (m *Manager) canRollback(task *Task, state *State) bool {
	if task == nil || state == nil {
		return false
	}
	return strings.TrimSpace(state.PreviousVersion) != "" && task.Terminal()
}
