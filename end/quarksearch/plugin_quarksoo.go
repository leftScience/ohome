package quarksearch

import (
	"context"
	"crypto/md5"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

type QuarksooPlugin struct{}

func (QuarksooPlugin) Name() string { return "quarksoo" }

func (QuarksooPlugin) Search(ctx context.Context, client *http.Client, keyword string, ext map[string]any) ([]SearchResult, error) {
	searchURL := fmt.Sprintf("https://quarksoo.cc/search.php?q=%s", url.QueryEscape(strings.TrimSpace(keyword)))
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, searchURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", defaultUserAgent)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
	req.Header.Set("Referer", "https://quarksoo.cc/")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("quarksoo 请求失败：%w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("quarksoo 返回状态码 %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	pattern := regexp.MustCompile(`<tr>\s*<td>([^<]+)</td>\s*<td>\s*<a[^>]*href\s*=\s*["']([^"']+)["'][^>]*>`)
	matches := pattern.FindAllStringSubmatch(string(body), -1)
	results := make([]SearchResult, 0, len(matches))

	for _, match := range matches {
		if len(match) < 3 {
			continue
		}
		title := strings.TrimSpace(match[1])
		if title == "" || strings.Contains(title, "剧名") {
			continue
		}

		rawURL := normalizeQuarkURL(match[2])
		if rawURL == "" || !strings.Contains(rawURL, "pan.quark.cn") {
			continue
		}

		hash := md5.Sum([]byte(title + "|" + rawURL))
		results = append(results, SearchResult{
			UniqueID: fmt.Sprintf("quarksoo-%x", hash[:8]),
			Title:    title,
			Content:  title,
			Datetime: time.Now(),
			Links: []Link{
				{
					Type:     "quark",
					URL:      rawURL,
					Password: extractPasswordFromURL(rawURL),
				},
			},
		})
	}

	return filterResultsByKeyword(results, keyword), nil
}
