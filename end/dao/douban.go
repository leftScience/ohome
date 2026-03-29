package dao

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"ohome/service/dto"
	"strings"
	"time"
)

type DoubanDao struct {
	BaseDao
}

const doubanBaseURL = "https://m.douban.com/rexxar/api/v2"

func (d *DoubanDao) GetRecentHot(ctx context.Context, subject string, query url.Values) (dto.DoubanRecentHotResp, error) {
	subject = strings.TrimSpace(subject)
	if subject != "movie" && subject != "tv" {
		return dto.DoubanRecentHotResp{}, errors.New("豆瓣类型仅支持 movie 或 tv")
	}

	fullURL := strings.TrimRight(doubanBaseURL, "/") + "/subject/recent_hot/" + subject

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fullURL, nil)
	if err != nil {
		return dto.DoubanRecentHotResp{}, err
	}
	if len(query) > 0 {
		req.URL.RawQuery = query.Encode()
	}

	// 尽量模拟 douban-api-main 的请求头，避免被豆瓣拦截
	req.Header.Set("User-Agent", "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1")
	req.Header.Set("Referer", "https://m.douban.com/")
	req.Header.Set("Accept", "application/json, text/plain, */*")
	req.Header.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
	req.Header.Set("Connection", "keep-alive")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return dto.DoubanRecentHotResp{}, err
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return dto.DoubanRecentHotResp{}, err
	}
	if resp.StatusCode != http.StatusOK {
		return dto.DoubanRecentHotResp{}, errors.New(string(raw))
	}

	var parsed dto.DoubanRecentHotResp
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return dto.DoubanRecentHotResp{}, err
	}
	return parsed, nil
}

func (d *DoubanDao) FetchImage(ctx context.Context, rawURL string) (dto.DoubanImage, int, error) {
	rawURL = strings.TrimSpace(rawURL)
	if rawURL == "" {
		return dto.DoubanImage{}, 0, errors.New("链接不能为空")
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return dto.DoubanImage{}, 0, err
	}

	applyImageHeaders(req)

	client := &http.Client{
		Timeout: 30 * time.Second,
		CheckRedirect: func(nextReq *http.Request, via []*http.Request) error {
			if len(via) >= 5 {
				return errors.New("重定向次数过多")
			}
			host := strings.ToLower(strings.TrimSpace(nextReq.URL.Hostname()))
			if !strings.HasSuffix(host, ".doubanio.com") || !strings.HasPrefix(host, "img") {
				return errors.New("重定向被阻止")
			}
			applyImageHeaders(nextReq)
			return nil
		},
	}
	resp, err := client.Do(req)
	if err != nil {
		return dto.DoubanImage{}, 0, err
	}

	contentType := strings.TrimSpace(resp.Header.Get("Content-Type"))
	if contentType == "" {
		contentType = "image/jpeg"
	}

	img := dto.DoubanImage{
		ContentType:   contentType,
		ContentLength: resp.ContentLength,
		Body:          resp.Body,
		CacheControl:  strings.TrimSpace(resp.Header.Get("Cache-Control")),
		ETag:          strings.TrimSpace(resp.Header.Get("ETag")),
		LastModified:  strings.TrimSpace(resp.Header.Get("Last-Modified")),
	}
	return img, resp.StatusCode, nil
}

func applyImageHeaders(req *http.Request) {
	req.Header.Set("User-Agent", "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1")
	req.Header.Set("Referer", "https://m.douban.com/")
	req.Header.Set("Accept", "image/avif,image/webp,image/apng,image/*,*/*;q=0.8")
	req.Header.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
	req.Header.Set("Connection", "keep-alive")
}
