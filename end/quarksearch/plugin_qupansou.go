package quarksearch

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

type QuPanSouPlugin struct{}

func (QuPanSouPlugin) Name() string { return "qupansou" }

func (QuPanSouPlugin) Search(ctx context.Context, client *http.Client, keyword string, ext map[string]any) ([]SearchResult, error) {
	payload := map[string]any{
		"style":   "get",
		"datasrc": "search",
		"query": map[string]any{
			"id":         "",
			"datetime":   "",
			"courseid":   1,
			"categoryid": "",
			"filetypeid": "",
			"filetype":   "",
			"reportid":   "",
			"validid":    "",
			"searchtext": keyword,
		},
		"page": map[string]any{
			"pageSize":  1000,
			"pageIndex": 1,
		},
		"order": map[string]any{
			"prop":  "sort",
			"order": "desc",
		},
		"message": "请求资源列表数据",
	}

	raw, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://v.funletu.com/search", bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", defaultUserAgent)
	req.Header.Set("Referer", "https://pan.funletu.com/")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("qupansou 请求失败：%w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("qupansou 返回状态码 %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var apiResp quPanSouResponse
	if err := json.Unmarshal(body, &apiResp); err != nil {
		return nil, fmt.Errorf("qupansou 响应解析失败：%w", err)
	}
	if apiResp.Status != 200 {
		return nil, fmt.Errorf("qupansou 接口错误：%s", strings.TrimSpace(apiResp.Message))
	}

	results := make([]SearchResult, 0, len(apiResp.Data))
	for _, item := range apiResp.Data {
		rawURL := normalizeQuarkURL(item.URL)
		if rawURL == "" {
			continue
		}
		results = append(results, SearchResult{
			UniqueID: fmt.Sprintf("qupansou-%d", item.ID),
			Title:    cleanText(item.Title),
			Content:  cleanText(item.Title + "\n" + item.FileType + "\n" + item.Size),
			Datetime: parseTime(item.UpdateTime),
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

type quPanSouResponse struct {
	Data    []quPanSouItem `json:"data"`
	Status  int            `json:"status"`
	Message string         `json:"message"`
}

type quPanSouItem struct {
	ID         int    `json:"id"`
	Title      string `json:"title"`
	URL        string `json:"url"`
	FileType   string `json:"filetype"`
	Size       string `json:"size"`
	UpdateTime string `json:"updatetime"`
}
