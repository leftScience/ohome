package updater

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

func FetchManifest(url string) (ServerManifest, error) {
	if strings.TrimSpace(url) == "" {
		return ServerManifest{}, fmt.Errorf("未配置更新清单地址")
	}
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
		return ServerManifest{}, fmt.Errorf("更新清单缺少版本号")
	}
	return manifest, nil
}

func FetchManifestWithFallback(urls []string) (ServerManifest, error) {
	candidates := make([]string, 0, len(urls))
	failures := make([]string, 0, len(urls))
	for _, url := range urls {
		trimmed := strings.TrimSpace(url)
		if trimmed == "" {
			continue
		}
		candidates = append(candidates, trimmed)
		manifest, err := FetchManifest(trimmed)
		if err == nil {
			return manifest, nil
		}
		failures = append(failures, fmt.Sprintf("%s -> %v", trimmed, err))
	}
	if len(candidates) == 0 {
		return ServerManifest{}, fmt.Errorf("未配置更新清单地址")
	}
	return ServerManifest{}, fmt.Errorf("拉取更新清单失败，已尝试 %d 个地址：%s", len(candidates), strings.Join(failures, " | "))
}
