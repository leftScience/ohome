//go:build windows

package updater

import (
	"os"
	"os/exec"
	"path/filepath"
	"syscall"

	"ohome/conf"
)

func startPortableServerDetached(version string) error {
	binary, err := resolvePortableServerBinary(version)
	if err != nil {
		return err
	}
	cmd := exec.Command(binary)
	cmd.Dir = filepath.Dir(binary)
	cmd.Env = append(os.Environ(), "OHOME_BASE_DIR="+conf.AppBaseDir())
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: 0x00000008}
	if err := cmd.Start(); err != nil {
		return err
	}
	return writePIDFile(PortableServerPIDFile(), cmd.Process.Pid)
}

func processRunning(pid int) bool {
	proc, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	return proc.Signal(syscall.Signal(0)) == nil
}
