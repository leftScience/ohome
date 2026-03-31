package updater

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"ohome/buildinfo"
	"ohome/conf"
	"ohome/global"
)

type managedProcess struct {
	cmd         *exec.Cmd
	waitCh      chan error
	intentional atomic.Bool
}

type RuntimeSupervisor struct {
	store              *Store
	baseDir            string
	embeddedServerPath string
	unexpectedExitHook func(error)

	mu           sync.Mutex
	current      *managedProcess
	shuttingDown bool
}

func NewRuntimeSupervisor(store *Store, baseDir string, embeddedServerPath string) *RuntimeSupervisor {
	return &RuntimeSupervisor{
		store:              store,
		baseDir:            filepath.Clean(baseDir),
		embeddedServerPath: filepath.Clean(embeddedServerPath),
	}
}

func (s *RuntimeSupervisor) SetUnexpectedExitHook(fn func(error)) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.unexpectedExitHook = fn
}

func (s *RuntimeSupervisor) BootstrapCurrentRelease(defaultVersion string) (string, string, error) {
	if err := s.store.ensure(); err != nil {
		return "", "", err
	}

	state, err := s.store.LoadState()
	if err != nil {
		return "", "", err
	}

	version := strings.TrimSpace(defaultVersion)
	if version == "" {
		version = "0.0.1"
	}
	releasePath := filepath.Join(s.store.ReleasesDir(), version)
	runtimeChanged := strings.TrimSpace(state.RuntimeVersion) != "" &&
		strings.TrimSpace(state.RuntimeVersion) != buildinfo.CleanRuntimeVersion()
	if err := s.seedEmbeddedRelease(releasePath, runtimeChanged); err != nil {
		return "", "", err
	}
	if runtimeChanged {
		if err := setCurrentReleaseLink(s.store.CurrentReleaseLink(), releasePath); err != nil {
			return "", "", err
		}
		return version, releasePath, nil
	}

	if releasePath, err := resolveCurrentReleasePath(s.store.CurrentReleaseLink()); err == nil {
		serverPath := filepath.Join(releasePath, ServerExecutableName())
		if _, statErr := os.Stat(serverPath); statErr == nil {
			return filepath.Base(releasePath), releasePath, nil
		}
	}

	if err := setCurrentReleaseLink(s.store.CurrentReleaseLink(), releasePath); err != nil {
		return "", "", err
	}
	return version, releasePath, nil
}

func (s *RuntimeSupervisor) seedEmbeddedRelease(releasePath string, force bool) error {
	serverPath := filepath.Join(releasePath, ServerExecutableName())
	if !force {
		if _, err := os.Stat(serverPath); err == nil {
			return nil
		} else if !os.IsNotExist(err) {
			return err
		}
	}
	if err := copyExecutable(s.embeddedServerPath, serverPath); err != nil {
		return err
	}
	if global.Logger != nil {
		global.Logger.Infof("launcher seeded embedded server release=%s force=%t", releasePath, force)
	}
	return nil
}

func (s *RuntimeSupervisor) StartCurrentServer() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.current != nil {
		return nil
	}

	serverPath, err := resolveCurrentExecutable(s.store.CurrentReleaseLink())
	if err != nil {
		return err
	}
	cmd := exec.Command(serverPath)
	cmd.Dir = s.baseDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = withEnvValue(os.Environ(), conf.BaseDirEnv, s.baseDir)
	if err := cmd.Start(); err != nil {
		return err
	}

	process := &managedProcess{
		cmd:    cmd,
		waitCh: make(chan error, 1),
	}
	s.current = process
	go s.watchProcess(process)
	if global.Logger != nil {
		global.Logger.Infof("launcher started server pid=%d path=%s", cmd.Process.Pid, serverPath)
	}
	return nil
}

func (s *RuntimeSupervisor) RestartCurrentServer(timeout time.Duration) error {
	if err := s.stopCurrentServer(timeout, false); err != nil {
		return err
	}
	return s.StartCurrentServer()
}

func (s *RuntimeSupervisor) StopCurrentServer(timeout time.Duration) error {
	return s.stopCurrentServer(timeout, true)
}

func (s *RuntimeSupervisor) stopCurrentServer(timeout time.Duration, final bool) error {
	s.mu.Lock()
	process := s.current
	if final {
		s.shuttingDown = true
	}
	if process == nil {
		s.mu.Unlock()
		return nil
	}
	process.intentional.Store(true)
	waitCh := process.waitCh
	s.mu.Unlock()

	if err := terminateProcess(process.cmd.Process); err != nil && !errors.Is(err, os.ErrProcessDone) {
		return err
	}

	select {
	case err := <-waitCh:
		if err != nil {
			var exitErr *exec.ExitError
			if !errors.As(err, &exitErr) {
				return err
			}
		}
	case <-time.After(timeout):
		if err := process.cmd.Process.Kill(); err != nil && !errors.Is(err, os.ErrProcessDone) {
			return err
		}
		select {
		case <-waitCh:
		case <-time.After(2 * time.Second):
		}
		return fmt.Errorf("服务端进程退出超时，已强制终止")
	}

	return nil
}

func (s *RuntimeSupervisor) watchProcess(process *managedProcess) {
	err := process.cmd.Wait()
	process.waitCh <- err
	close(process.waitCh)

	s.mu.Lock()
	if s.current == process {
		s.current = nil
	}
	intentional := process.intentional.Load()
	shuttingDown := s.shuttingDown
	hook := s.unexpectedExitHook
	s.mu.Unlock()

	if intentional || shuttingDown {
		return
	}
	if hook != nil {
		hook(err)
	}
}

func resolveCurrentExecutable(linkPath string) (string, error) {
	releasePath, err := resolveCurrentReleasePath(linkPath)
	if err != nil {
		return "", err
	}
	serverPath := filepath.Join(releasePath, ServerExecutableName())
	if _, err := os.Stat(serverPath); err != nil {
		return "", err
	}
	return serverPath, nil
}

func withEnvValue(env []string, key string, value string) []string {
	prefix := key + "="
	replaced := false
	result := make([]string, 0, len(env)+1)
	for _, item := range env {
		if strings.HasPrefix(item, prefix) {
			result = append(result, prefix+value)
			replaced = true
			continue
		}
		result = append(result, item)
	}
	if !replaced {
		result = append(result, prefix+value)
	}
	return result
}
