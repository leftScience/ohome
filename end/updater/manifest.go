package updater

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

func FetchManifest(url string) (ServerManifest, error) {
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(strings.TrimSpace(url))
	if err != nil {
		return ServerManifest{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return ServerManifest{}, fmt.Errorf("拉取更新清单失败: %s", resp.Status)
	}
	var manifest ServerManifest
	if err := json.NewDecoder(resp.Body).Decode(&manifest); err != nil {
		return ServerManifest{}, err
	}
	if strings.TrimSpace(manifest.Version) == "" {
		return ServerManifest{}, fmt.Errorf("更新清单缺少 version")
	}
	return manifest, nil
}

func CurrentPortableArtifactKey() string {
	switch runtime.GOOS {
	case "windows":
		return "windows_amd64"
	case "darwin":
		if runtime.GOARCH == "arm64" {
			return "darwin_arm64"
		}
		return "darwin_amd64"
	default:
		return runtime.GOOS + "_" + runtime.GOARCH
	}
}

func DownloadFile(url string, destination string) error {
	client := &http.Client{Timeout: 10 * time.Minute}
	resp, err := client.Get(strings.TrimSpace(url))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("下载失败: %s", resp.Status)
	}
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}
	file, err := os.Create(destination)
	if err != nil {
		return err
	}
	defer file.Close()
	_, err = io.Copy(file, resp.Body)
	return err
}

func ComputeSHA256(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}
