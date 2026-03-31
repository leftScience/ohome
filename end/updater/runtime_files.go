package updater

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
)

func downloadArtifact(tempDir string, taskID string, urls ...string) (string, error) {
	if err := os.MkdirAll(tempDir, 0o755); err != nil {
		return "", err
	}
	tmpFile, err := os.CreateTemp(tempDir, taskID+"-*.tar.gz")
	if err != nil {
		return "", err
	}
	defer tmpFile.Close()

	candidates := normalizeDownloadURLs(urls...)
	if len(candidates) == 0 {
		return "", fmt.Errorf("缺少更新包下载地址")
	}

	failures := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		if _, err := tmpFile.Seek(0, io.SeekStart); err != nil {
			return "", err
		}
		if err := tmpFile.Truncate(0); err != nil {
			return "", err
		}

		resp, err := http.Get(candidate)
		if err != nil {
			failures = append(failures, fmt.Sprintf("%s -> %v", candidate, err))
			continue
		}

		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			failures = append(failures, fmt.Sprintf("%s -> 下载更新包失败: %s", candidate, resp.Status))
			resp.Body.Close()
			continue
		}

		_, copyErr := io.Copy(tmpFile, resp.Body)
		resp.Body.Close()
		if copyErr != nil {
			failures = append(failures, fmt.Sprintf("%s -> %v", candidate, copyErr))
			continue
		}
		return tmpFile.Name(), nil
	}

	return "", fmt.Errorf("下载更新包失败，已尝试 %d 个地址：%s", len(candidates), strings.Join(failures, " | "))
}

func normalizeDownloadURLs(urls ...string) []string {
	result := make([]string, 0, len(urls))
	for _, raw := range urls {
		for _, candidate := range strings.Split(raw, ",") {
			trimmed := strings.TrimSpace(candidate)
			if trimmed == "" || slices.Contains(result, trimmed) {
				continue
			}
			result = append(result, trimmed)
		}
	}
	return result
}

func verifySHA256File(path string, expected string) error {
	expected = strings.ToLower(strings.TrimSpace(expected))
	if expected == "" {
		return fmt.Errorf("缺少更新包 SHA256")
	}
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return err
	}
	actual := hex.EncodeToString(hash.Sum(nil))
	if actual != expected {
		return fmt.Errorf("更新包校验失败: 期望 %s，实际 %s", expected, actual)
	}
	return nil
}

func extractServerArchive(archivePath string, releaseDir string, format string) error {
	return extractServerArchiveForPlatform(archivePath, releaseDir, format, runtime.GOOS)
}

func extractServerArchiveForPlatform(archivePath string, releaseDir string, format string, goos string) error {
	if err := os.RemoveAll(releaseDir); err != nil {
		return err
	}
	if err := os.MkdirAll(releaseDir, 0o755); err != nil {
		return err
	}

	serverPath := filepath.Join(releaseDir, ServerExecutableNameForGOOS(goos))
	switch normalizeArtifactFormat(format, archivePath) {
	case artifactFormatTarGz:
		return extractServerTarGz(archivePath, serverPath, goos)
	case artifactFormatZip:
		return extractServerZip(archivePath, serverPath, goos)
	default:
		return fmt.Errorf("不支持的更新包格式：%s", format)
	}
}

func ensureExecutable(path string) error {
	return os.Chmod(path, 0o755)
}

func copyExecutable(src string, dst string) error {
	input, err := os.Open(src)
	if err != nil {
		return err
	}
	defer input.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	output, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
	if err != nil {
		return err
	}
	if _, err := io.Copy(output, input); err != nil {
		output.Close()
		return err
	}
	if err := output.Close(); err != nil {
		return err
	}
	return ensureExecutable(dst)
}

func resolveCurrentReleasePath(linkPath string) (string, error) {
	info, err := os.Lstat(linkPath)
	if err != nil {
		return "", err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		resolved, err := filepath.EvalSymlinks(linkPath)
		if err != nil {
			return "", err
		}
		return filepath.Clean(resolved), nil
	}
	if info.IsDir() {
		return "", fmt.Errorf("%s 不是有效的当前版本指针文件", linkPath)
	}
	payload, err := os.ReadFile(linkPath)
	if err != nil {
		return "", err
	}
	target := strings.TrimSpace(string(payload))
	if target == "" {
		return "", fmt.Errorf("当前版本指针为空：%s", linkPath)
	}
	return filepath.Clean(target), nil
}

func setCurrentReleaseLink(linkPath string, target string) error {
	if strings.TrimSpace(target) == "" {
		return fmt.Errorf("目标版本目录不能为空")
	}
	if err := os.MkdirAll(filepath.Dir(linkPath), 0o755); err != nil {
		return err
	}
	tmpPath := linkPath + ".tmp"
	if err := os.WriteFile(tmpPath, []byte(filepath.Clean(target)), 0o644); err != nil {
		return err
	}
	if err := removeLinkOrFile(linkPath); err != nil {
		_ = os.Remove(tmpPath)
		return err
	}
	return os.Rename(tmpPath, linkPath)
}

func rollbackCurrentRelease(linkPath string, previousReleasePath string) error {
	if strings.TrimSpace(previousReleasePath) == "" {
		return fmt.Errorf("缺少上一版本目录")
	}
	return setCurrentReleaseLink(linkPath, previousReleasePath)
}

func removeLinkOrFile(path string) error {
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if info.IsDir() && info.Mode()&os.ModeSymlink == 0 {
		return fmt.Errorf("%s 不是符号链接，拒绝覆盖目录", path)
	}
	return os.Remove(path)
}

func extractServerTarGz(archivePath string, serverPath string, goos string) error {
	file, err := os.Open(archivePath)
	if err != nil {
		return err
	}
	defer file.Close()

	gzipReader, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer gzipReader.Close()

	tarReader := tar.NewReader(gzipReader)
	return extractServerFromTarReader(tarReader, serverPath, goos)
}

func extractServerFromTarReader(tarReader *tar.Reader, serverPath string, goos string) error {
	foundServer := false
	expectedName := ServerExecutableNameForGOOS(goos)
	for {
		header, err := tarReader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		switch header.Typeflag {
		case tar.TypeDir:
			continue
		case tar.TypeReg:
			if filepath.Base(header.Name) != expectedName {
				continue
			}
			out, err := os.OpenFile(serverPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
			if err != nil {
				return err
			}
			if _, err := io.Copy(out, tarReader); err != nil {
				out.Close()
				return err
			}
			if err := out.Close(); err != nil {
				return err
			}
			foundServer = true
		}
	}
	if !foundServer {
		return fmt.Errorf("更新包中缺少 %s 可执行文件", expectedName)
	}
	return ensureExecutable(serverPath)
}

func extractServerZip(archivePath string, serverPath string, goos string) error {
	reader, err := zip.OpenReader(archivePath)
	if err != nil {
		return err
	}
	defer reader.Close()

	expectedName := ServerExecutableNameForGOOS(goos)
	for _, file := range reader.File {
		if file.FileInfo().IsDir() || filepath.Base(file.Name) != expectedName {
			continue
		}
		input, err := file.Open()
		if err != nil {
			return err
		}
		output, err := os.OpenFile(serverPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
		if err != nil {
			input.Close()
			return err
		}
		if _, err := io.Copy(output, input); err != nil {
			input.Close()
			output.Close()
			return err
		}
		if err := input.Close(); err != nil {
			output.Close()
			return err
		}
		if err := output.Close(); err != nil {
			return err
		}
		return ensureExecutable(serverPath)
	}
	return fmt.Errorf("更新包中缺少 %s 可执行文件", expectedName)
}
