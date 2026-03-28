package updater

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"

	"ohome/conf"
)

func serverBinaryName() string {
	if runtime.GOOS == "windows" {
		return "ohome.exe"
	}
	return "ohome"
}

func resolvePortableServerBinary(version string) (string, error) {
	version = strings.TrimSpace(version)
	if version == "" {
		return "", fmt.Errorf("版本号不能为空")
	}
	path := filepath.Join(PortableVersionsDir(), version, serverBinaryName())
	if _, err := os.Stat(path); err != nil {
		return "", err
	}
	return path, nil
}

func RunCurrentServerForeground() error {
	version, err := readCurrentPortableVersion()
	if err != nil {
		return err
	}
	binary, err := resolvePortableServerBinary(version)
	if err != nil {
		return err
	}
	cmd := exec.Command(binary)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Dir = filepath.Dir(binary)
	cmd.Env = append(os.Environ(), "OHOME_BASE_DIR="+conf.AppBaseDir())
	if err := cmd.Start(); err != nil {
		return err
	}
	if err := writePIDFile(PortableServerPIDFile(), cmd.Process.Pid); err != nil {
		return err
	}
	defer removePIDFile(PortableServerPIDFile())
	return cmd.Wait()
}

func readCurrentPortableVersion() (string, error) {
	path := PortableCurrentVersionFile()
	payload, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	value := strings.TrimSpace(string(payload))
	if value == "" {
		return "", fmt.Errorf("current.txt 为空")
	}
	return value, nil
}

func writeCurrentPortableVersion(version string) error {
	path := PortableCurrentVersionFile()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(strings.TrimSpace(version)+"\n"), 0o644)
}

func writePIDFile(path string, pid int) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(strconv.Itoa(pid)), 0o644)
}

func readPIDFile(path string) (int, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(strings.TrimSpace(string(payload)))
}

func removePIDFile(path string) {
	_ = os.Remove(path)
}

func stopPortableServer() error {
	pid, err := readPIDFile(PortableServerPIDFile())
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	proc, err := os.FindProcess(pid)
	if err != nil {
		return err
	}
	if err := proc.Signal(syscall.SIGTERM); err != nil {
		_ = proc.Kill()
	}
	deadline := time.Now().Add(8 * time.Second)
	for time.Now().Before(deadline) {
		if !processRunning(pid) {
			removePIDFile(PortableServerPIDFile())
			return nil
		}
		time.Sleep(300 * time.Millisecond)
	}
	_ = proc.Kill()
	removePIDFile(PortableServerPIDFile())
	return nil
}

func waitForHealth(url string, timeout time.Duration) error {
	client := &http.Client{Timeout: 5 * time.Second}
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		resp, err := client.Get(url)
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				return nil
			}
		}
		time.Sleep(time.Second)
	}
	return fmt.Errorf("健康检查超时: %s", url)
}
