package service

import (
	"bytes"
	"context"
	"crypto/md5"
	"crypto/sha1"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"io"
	"mime"
	"mime/multipart"
	"net"
	"net/http"
	"net/url"
	"ohome/global"
	"ohome/model"
	"path"
	"strconv"
	"strings"
	"sync"
	"time"

	"gorm.io/gorm"
)

const (
	quarkDefaultDriveBaseURL = "https://drive.quark.cn/1/clouddrive"
	quarkDriveUserAgent      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) quark-cloud-drive/2.5.20 Chrome/100.0.4896.160 Electron/18.3.5.4-b478491100 Safari/537.36 Channel/pckk_other_ch"
	quarkDriveReferer        = "https://pan.quark.cn"
	quarkCookieConfigKey     = "quark_cookies"
	quarkAPITimeout          = 60 * time.Second
	quarkFileLinkTTL         = 10 * time.Minute
	quarkFileLinkBuffer      = 30 * time.Second
	quarkListRetryCount      = 2
	quarkListSortByNameAsc   = "file_type:asc,file_name:asc"
	quarkListSortByUpdated   = "updated_at:desc,file_name:asc"
	quarkListSortByOldest    = "updated_at:asc,file_name:asc"
)

var errQuarkEntryNotFound = errors.New("quark entry not found")

type quarkDriveFile struct {
	Fid        string `json:"fid"`
	FileName   string `json:"file_name"`
	Category   int    `json:"category"`
	Size       int64  `json:"size"`
	LCreatedAt int64  `json:"l_created_at"`
	LUpdatedAt int64  `json:"l_updated_at"`
	File       bool   `json:"file"`
	Dir        bool   `json:"dir"`
	CreatedAt  int64  `json:"created_at"`
	UpdatedAt  int64  `json:"updated_at"`
	Thumbnail  string `json:"thumbnail"`
	FormatType string `json:"format_type"`
}

func (f quarkDriveFile) Name() string {
	return html.UnescapeString(strings.TrimSpace(f.FileName))
}

func (f quarkDriveFile) IsDir() bool {
	if f.Dir {
		return true
	}
	return !f.File
}

func (f quarkDriveFile) UpdatedUnix() int64 {
	if f.UpdatedAt > 0 {
		return normalizeQuarkTimestamp(f.UpdatedAt)
	}
	return normalizeQuarkTimestamp(f.LUpdatedAt)
}

func (f quarkDriveFile) CreatedUnix() int64 {
	if f.CreatedAt > 0 {
		return normalizeQuarkTimestamp(f.CreatedAt)
	}
	return normalizeQuarkTimestamp(f.LCreatedAt)
}

func (f quarkDriveFile) UpdatedRaw() string {
	if f.UpdatedAt > 0 {
		return strconv.FormatInt(f.UpdatedAt, 10)
	}
	if f.LUpdatedAt > 0 {
		return strconv.FormatInt(f.LUpdatedAt, 10)
	}
	return ""
}

func (f quarkDriveFile) CreatedRaw() string {
	if f.CreatedAt > 0 {
		return strconv.FormatInt(f.CreatedAt, 10)
	}
	if f.LCreatedAt > 0 {
		return strconv.FormatInt(f.LCreatedAt, 10)
	}
	return ""
}

type quarkUploadPreResponse struct {
	Data struct {
		TaskID    string `json:"task_id"`
		UploadID  string `json:"upload_id"`
		ObjKey    string `json:"obj_key"`
		UploadURL string `json:"upload_url"`
		Fid       string `json:"fid"`
		Bucket    string `json:"bucket"`
		Callback  struct {
			CallbackURL  string `json:"callbackUrl"`
			CallbackBody string `json:"callbackBody"`
		} `json:"callback"`
		FormatType string `json:"format_type"`
		Size       int64  `json:"size"`
		AuthInfo   string `json:"auth_info"`
	} `json:"data"`
	Metadata struct {
		PartSize int `json:"part_size"`
	} `json:"metadata"`
}

type quarkUploadHashResponse struct {
	Data struct {
		Finish bool `json:"finish"`
	} `json:"data"`
}

type quarkUploadAuthResponse struct {
	Data struct {
		AuthKey string `json:"auth_key"`
	} `json:"data"`
}

type quarkFileLinkResponse struct {
	Data []struct {
		FileURL string `json:"download_url"`
		Size    int64  `json:"size"`
	} `json:"data"`
}

type quarkFileLink struct {
	URL  string
	Size int64
}

type cachedQuarkFileLink struct {
	link      quarkFileLink
	expiresAt time.Time
}

var quarkFileLinkCache = struct {
	mu    sync.RWMutex
	items map[string]cachedQuarkFileLink
}{
	items: make(map[string]cachedQuarkFileLink),
}

func newManagedQuarkClient() (*quarkClient, error) {
	cookie, err := loadPrimaryQuarkCookie()
	if err != nil {
		return nil, err
	}
	client := newQuarkClient(cookie)
	client.persistCookie = true
	client.driveBaseURL = quarkDefaultDriveBaseURL
	return client, nil
}

func loadPrimaryQuarkCookie() (string, error) {
	_, _, cookie, err := loadPrimaryQuarkCookieRecord()
	return cookie, err
}

func loadPrimaryQuarkCookieRecord() (model.Config, int, string, error) {
	cfg, err := configDao.GetByKey(quarkCookieConfigKey)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return model.Config{}, -1, "", errors.New("未配置 quark_cookies（请在参数管理中新增 key=quark_cookies）")
		}
		return model.Config{}, -1, "", err
	}
	if strings.TrimSpace(cfg.Value) == "" {
		return cfg, -1, "", errors.New("quark_cookies 为空")
	}
	lines := splitCookieConfigLines(cfg.Value)
	for i, line := range lines {
		if cookie := strings.TrimSpace(line); cookie != "" {
			return cfg, i, cookie, nil
		}
	}
	return cfg, -1, "", errors.New("quark_cookies 无有效内容")
}

func updatePrimaryQuarkCookie(cookieLine string) error {
	cookieLine = strings.TrimSpace(cookieLine)
	if cookieLine == "" {
		return errors.New("quark_cookies 无有效内容")
	}
	cfg, lineIndex, _, err := loadPrimaryQuarkCookieRecord()
	if err != nil {
		return err
	}
	lines := splitCookieConfigLines(cfg.Value)
	if len(lines) == 0 {
		lines = []string{cookieLine}
	} else if lineIndex >= 0 {
		lines[lineIndex] = cookieLine
	} else {
		lines = append(lines, cookieLine)
	}
	newValue := strings.Join(lines, "\n")
	if cfg.Value == newValue {
		return nil
	}
	return global.DB.Model(&model.Config{}).Where("id = ?", cfg.ID).Update("value", newValue).Error
}

func splitCookieConfigLines(raw string) []string {
	normalized := strings.ReplaceAll(raw, "\r\n", "\n")
	normalized = strings.ReplaceAll(normalized, "\r", "\n")
	return strings.Split(normalized, "\n")
}

func (c *quarkClient) syncCookieFromResponse(resp *http.Response) {
	if c == nil || resp == nil {
		return
	}
	updated, changed := mergeRefreshCookies(c.cookie, resp.Cookies())
	if !changed || strings.TrimSpace(updated) == "" {
		return
	}
	c.cookie = updated
	c.mparam = matchMParamFromCookie(updated)
	if !c.persistCookie {
		return
	}
	if err := updatePrimaryQuarkCookie(updated); err != nil && global.Logger != nil {
		global.Logger.Warnf("更新 quark_cookies 失败: %v", err)
	}
}

func mergeRefreshCookies(raw string, cookies []*http.Cookie) (string, bool) {
	updates := map[string]string{}
	for _, cookie := range cookies {
		if cookie == nil || strings.TrimSpace(cookie.Value) == "" {
			continue
		}
		switch cookie.Name {
		case "__puus", "__pus":
			updates[cookie.Name] = cookie.Value
		}
	}
	if len(updates) == 0 {
		return strings.TrimSpace(raw), false
	}
	return setCookieValues(raw, updates)
}

func setCookieValues(raw string, updates map[string]string) (string, bool) {
	order := make([]string, 0)
	values := make(map[string]string)
	for _, part := range strings.Split(strings.TrimSpace(raw), ";") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		key, value, ok := strings.Cut(part, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		value = strings.TrimSpace(value)
		if key == "" {
			continue
		}
		if _, exists := values[key]; !exists {
			order = append(order, key)
		}
		values[key] = value
	}

	changed := false
	for key, value := range updates {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		if current, ok := values[key]; !ok {
			order = append(order, key)
			values[key] = value
			changed = true
		} else if current != value {
			values[key] = value
			changed = true
		}
	}
	if !changed {
		return strings.TrimSpace(raw), false
	}

	parts := make([]string, 0, len(order))
	seen := make(map[string]struct{}, len(order))
	for _, key := range order {
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		value := strings.TrimSpace(values[key])
		if value == "" {
			continue
		}
		parts = append(parts, key+"="+value)
	}
	return strings.Join(parts, "; "), true
}

func logQuarkWarnf(format string, args ...any) {
	if global.Logger == nil {
		return
	}
	global.Logger.Warnf(format, args...)
}

func summarizeQuarkEntryNames(entries []quarkDriveFile, limit int) string {
	if len(entries) == 0 {
		return "[]"
	}
	if limit <= 0 || limit > len(entries) {
		limit = len(entries)
	}
	names := make([]string, 0, limit+1)
	for i := 0; i < limit; i++ {
		name := entries[i].Name()
		if name == "" {
			name = entries[i].Fid
		}
		names = append(names, name)
	}
	if len(entries) > limit {
		names = append(names, fmt.Sprintf("...(%d more)", len(entries)-limit))
	}
	return "[" + strings.Join(names, ", ") + "]"
}

func normalizeQuarkTimestamp(value int64) int64 {
	if value <= 0 {
		return 0
	}
	if value > 9999999999 {
		return value / 1000
	}
	return value
}

func ensureLeadingSlash(value string) string {
	if strings.HasPrefix(value, "/") {
		return value
	}
	return "/" + value
}

func getCachedFileLink(fid string, now time.Time, minRemaining time.Duration) (quarkFileLink, bool) {
	fid = strings.TrimSpace(fid)
	if fid == "" {
		return quarkFileLink{}, false
	}

	quarkFileLinkCache.mu.RLock()
	cached, ok := quarkFileLinkCache.items[fid]
	quarkFileLinkCache.mu.RUnlock()
	if !ok || strings.TrimSpace(cached.link.URL) == "" {
		return quarkFileLink{}, false
	}
	if !cached.expiresAt.After(now.Add(minRemaining)) {
		return quarkFileLink{}, false
	}
	return cached.link, true
}

func cacheFileLink(fid string, link quarkFileLink, now time.Time) {
	fid = strings.TrimSpace(fid)
	if fid == "" || strings.TrimSpace(link.URL) == "" {
		return
	}

	quarkFileLinkCache.mu.Lock()
	quarkFileLinkCache.items[fid] = cachedQuarkFileLink{
		link:      link,
		expiresAt: resolveFileLinkExpiry(link.URL, now),
	}
	quarkFileLinkCache.mu.Unlock()
}

func resolveFileLinkExpiry(fileURL string, now time.Time) time.Time {
	parsedURL, err := url.Parse(strings.TrimSpace(fileURL))
	if err == nil {
		rawExpires := strings.TrimSpace(parsedURL.Query().Get("Expires"))
		if rawExpires != "" {
			expiresAt, parseErr := strconv.ParseInt(rawExpires, 10, 64)
			if parseErr == nil {
				expiry := time.Unix(expiresAt, 0)
				if expiry.After(now) {
					return expiry
				}
			}
		}
	}
	return now.Add(quarkFileLinkTTL)
}

func (c *quarkClient) apiClient() *http.Client {
	if c != nil && c.httpClient != nil {
		return c.httpClient
	}
	return &http.Client{Timeout: quarkAPITimeout}
}

func (c *quarkClient) transferClient() *http.Client {
	base := c.apiClient()
	cloned := *base
	cloned.Timeout = 0
	return &cloned
}

func (c *quarkClient) driveRequest(ctx context.Context, method, pathname string, query map[string]string, payload any) (quarkAPIResponse, []byte, http.Header, error) {
	baseURL := strings.TrimRight(strings.TrimSpace(c.driveBaseURL), "/")
	if baseURL == "" {
		baseURL = quarkDefaultDriveBaseURL
	}
	u, err := url.Parse(baseURL + ensureLeadingSlash(pathname))
	if err != nil {
		return quarkAPIResponse{}, nil, nil, err
	}
	params := u.Query()
	params.Set("pr", "ucpro")
	params.Set("fr", "pc")
	for key, value := range query {
		params.Set(key, value)
	}
	u.RawQuery = params.Encode()

	var body io.Reader
	if payload != nil {
		b, err := json.Marshal(payload)
		if err != nil {
			return quarkAPIResponse{}, nil, nil, err
		}
		body = bytes.NewReader(b)
	}

	req, err := http.NewRequestWithContext(ctx, method, u.String(), body)
	if err != nil {
		return quarkAPIResponse{}, nil, nil, err
	}
	req.Header.Set("Accept", "application/json, text/plain, */*")
	req.Header.Set("Referer", quarkDriveReferer)
	req.Header.Set("User-Agent", quarkDriveUserAgent)
	if strings.TrimSpace(c.cookie) != "" {
		req.Header.Set("Cookie", c.cookie)
	}
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.apiClient().Do(req)
	if err != nil {
		if pathname == "/file/sort" {
			logQuarkWarnf("[quarkFs:list] quark request failed method=%s path=%s query=%v err=%v", method, pathname, query, err)
		}
		return quarkAPIResponse{Status: 500, Code: 1, Message: "request error"}, nil, nil, err
	}
	defer resp.Body.Close()
	c.syncCookieFromResponse(resp)
	respBody, _ := io.ReadAll(resp.Body)

	var apiResp quarkAPIResponse
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		if resp.StatusCode >= http.StatusBadRequest {
			msg := strings.TrimSpace(string(respBody))
			if msg == "" {
				msg = http.StatusText(resp.StatusCode)
			}
			return quarkAPIResponse{Status: resp.StatusCode, Code: 1, Message: msg}, respBody, resp.Header, errors.New(msg)
		}
		return quarkAPIResponse{Status: resp.StatusCode, Code: 1, Message: "json decode error"}, respBody, resp.Header, err
	}
	if apiResp.Status == 0 {
		apiResp.Status = resp.StatusCode
	}
	if apiResp.Status >= http.StatusBadRequest || apiResp.Code != 0 {
		msg := strings.TrimSpace(apiResp.Message)
		if msg == "" {
			msg = strings.TrimSpace(string(respBody))
		}
		if msg == "" {
			msg = fmt.Sprintf("Quark 请求失败(%d)", resp.StatusCode)
		}
		return apiResp, respBody, resp.Header, errors.New(msg)
	}
	return apiResp, respBody, resp.Header, nil
}

func (c *quarkClient) listAll(ctx context.Context, parentFid string) ([]quarkDriveFile, error) {
	return c.listAllWithSort(ctx, parentFid, quarkListSortByNameAsc)
}

func (c *quarkClient) listAllWithSort(ctx context.Context, parentFid, sortExpr string) ([]quarkDriveFile, error) {
	const pageSize = 100
	page := 1
	files := make([]quarkDriveFile, 0, pageSize)
	sortExpr = strings.TrimSpace(sortExpr)
	if sortExpr == "" {
		sortExpr = quarkListSortByNameAsc
	}

	for {
		var (
			resp quarkAPIResponse
			err  error
		)
		for attempt := 0; attempt <= quarkListRetryCount; attempt++ {
			resp, _, _, err = c.driveRequest(ctx, http.MethodGet, "/file/sort", map[string]string{
				"pdir_fid":             parentFid,
				"_page":                strconv.Itoa(page),
				"_size":                strconv.Itoa(pageSize),
				"_fetch_total":         "1",
				"fetch_all_file":       "1",
				"fetch_risk_file_name": "1",
				"_sort":                sortExpr,
			}, nil)
			if err == nil {
				break
			}
			logQuarkWarnf("[quarkFs:list] file/sort retry parentFid=%s page=%d attempt=%d err=%v", parentFid, page, attempt+1, err)
			if !isRetryableQuarkTimeout(err) || attempt == quarkListRetryCount {
				return nil, err
			}
			time.Sleep(time.Duration(attempt+1) * time.Second)
		}

		var result struct {
			List []quarkDriveFile `json:"list"`
		}
		if err := json.Unmarshal(resp.Data, &result); err != nil {
			logQuarkWarnf("[quarkFs:list] file/sort decode data failed parentFid=%s page=%d err=%v body=%s", parentFid, page, err, strings.TrimSpace(string(resp.Data)))
			return nil, err
		}
		var metadata struct {
			Total int `json:"_total"`
		}
		if len(resp.Metadata) > 0 && string(resp.Metadata) != "null" {
			if err := json.Unmarshal(resp.Metadata, &metadata); err != nil {
				logQuarkWarnf("[quarkFs:list] file/sort decode metadata failed parentFid=%s page=%d err=%v body=%s", parentFid, page, err, strings.TrimSpace(string(resp.Metadata)))
			}
		}
		for i := range result.List {
			result.List[i].FileName = result.List[i].Name()
		}
		files = append(files, result.List...)
		logQuarkWarnf("[quarkFs:list] file/sort success parentFid=%s page=%d count=%d total=%d sample=%s", parentFid, page, len(result.List), metadata.Total, summarizeQuarkEntryNames(result.List, 5))

		if metadata.Total > 0 {
			if page*pageSize >= metadata.Total {
				break
			}
		} else if len(result.List) == 0 || len(result.List) < pageSize {
			break
		}
		page++
	}

	logQuarkWarnf("[quarkFs:list] file/sort done parentFid=%s totalCount=%d", parentFid, len(files))
	return files, nil
}

func (c *quarkClient) listPage(ctx context.Context, parentFid string, page, size int) ([]quarkDriveFile, int, error) {
	return c.listPageWithSort(ctx, parentFid, page, size, quarkListSortByNameAsc)
}

func (c *quarkClient) listPageWithSort(ctx context.Context, parentFid string, page, size int, sortExpr string) ([]quarkDriveFile, int, error) {
	if page <= 0 {
		page = 1
	}
	if size <= 0 {
		size = 1
	}
	sortExpr = strings.TrimSpace(sortExpr)
	if sortExpr == "" {
		sortExpr = quarkListSortByNameAsc
	}

	var (
		resp quarkAPIResponse
		err  error
	)
	for attempt := 0; attempt <= quarkListRetryCount; attempt++ {
		resp, _, _, err = c.driveRequest(ctx, http.MethodGet, "/file/sort", map[string]string{
			"pdir_fid":             parentFid,
			"_page":                strconv.Itoa(page),
			"_size":                strconv.Itoa(size),
			"_fetch_total":         "1",
			"fetch_all_file":       "1",
			"fetch_risk_file_name": "1",
			"_sort":                sortExpr,
		}, nil)
		if err == nil {
			break
		}
		logQuarkWarnf("[quarkFs:list] file/sort page retry parentFid=%s page=%d size=%d attempt=%d err=%v", parentFid, page, size, attempt+1, err)
		if !isRetryableQuarkTimeout(err) || attempt == quarkListRetryCount {
			return nil, 0, err
		}
		time.Sleep(time.Duration(attempt+1) * time.Second)
	}

	var result struct {
		List []quarkDriveFile `json:"list"`
	}
	if err := json.Unmarshal(resp.Data, &result); err != nil {
		logQuarkWarnf("[quarkFs:list] file/sort page decode data failed parentFid=%s page=%d size=%d err=%v body=%s", parentFid, page, size, err, strings.TrimSpace(string(resp.Data)))
		return nil, 0, err
	}

	var metadata struct {
		Total int `json:"_total"`
	}
	if len(resp.Metadata) > 0 && string(resp.Metadata) != "null" {
		if err := json.Unmarshal(resp.Metadata, &metadata); err != nil {
			logQuarkWarnf("[quarkFs:list] file/sort page decode metadata failed parentFid=%s page=%d size=%d err=%v body=%s", parentFid, page, size, err, strings.TrimSpace(string(resp.Metadata)))
		}
	}

	for i := range result.List {
		result.List[i].FileName = result.List[i].Name()
	}

	logQuarkWarnf("[quarkFs:list] file/sort page success parentFid=%s page=%d size=%d count=%d total=%d sample=%s", parentFid, page, size, len(result.List), metadata.Total, summarizeQuarkEntryNames(result.List, 5))
	return result.List, metadata.Total, nil
}

func isRetryableQuarkTimeout(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, context.Canceled) {
		return false
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	var netErr net.Error
	return errors.As(err, &netErr) && netErr.Timeout()
}

func (c *quarkClient) findChildByName(ctx context.Context, parentFid, name string) (quarkDriveFile, error) {
	children, err := c.listAll(ctx, parentFid)
	if err != nil {
		logQuarkWarnf("[quarkFs:path] find child failed parentFid=%s name=%s err=%v", parentFid, name, err)
		return quarkDriveFile{}, err
	}
	for _, child := range children {
		if child.Name() == name {
			child.FileName = child.Name()
			return child, nil
		}
	}
	logQuarkWarnf("[quarkFs:path] child not found parentFid=%s name=%s children=%s", parentFid, name, summarizeQuarkEntryNames(children, 8))
	return quarkDriveFile{}, errQuarkEntryNotFound
}

func (c *quarkClient) makeDir(ctx context.Context, parentFid, dirName string) (quarkDriveFile, error) {
	resp, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file", nil, map[string]any{
		"dir_init_lock": false,
		"dir_path":      "",
		"file_name":     dirName,
		"pdir_fid":      parentFid,
	})
	if err != nil {
		return quarkDriveFile{}, err
	}

	var created quarkDriveFile
	if len(resp.Data) > 0 && string(resp.Data) != "null" {
		_ = json.Unmarshal(resp.Data, &created)
	}
	created.FileName = strings.TrimSpace(created.FileName)
	if created.FileName == "" {
		created.FileName = dirName
	}
	created.Dir = true
	created.File = false
	time.Sleep(time.Second)
	return created, nil
}

func (c *quarkClient) rename(ctx context.Context, fid, newName string) error {
	_, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/rename", nil, map[string]any{
		"fid":       fid,
		"file_name": newName,
	})
	return err
}

func (c *quarkClient) move(ctx context.Context, fid, targetDirFid string) error {
	_, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/move", nil, map[string]any{
		"action_type":  1,
		"exclude_fids": []string{},
		"filelist":     []string{fid},
		"to_pdir_fid":  targetDirFid,
	})
	return err
}

func (c *quarkClient) delete(ctx context.Context, fid string) error {
	_, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/delete", nil, map[string]any{
		"action_type":  1,
		"exclude_fids": []string{},
		"filelist":     []string{fid},
	})
	return err
}

func (c *quarkClient) getFileLink(ctx context.Context, fid string) (quarkFileLink, error) {
	now := time.Now()
	if cached, ok := getCachedFileLink(fid, now, quarkFileLinkBuffer); ok {
		return cached, nil
	}

	resp, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/download", nil, map[string]any{
		"fids": []string{fid},
	})
	if err != nil {
		if cached, ok := getCachedFileLink(fid, now, 0); ok {
			logQuarkWarnf("[quarkFs:stream] reuse cached file link after refresh failed fid=%s err=%v", strings.TrimSpace(fid), err)
			return cached, nil
		}
		return quarkFileLink{}, err
	}

	var data quarkFileLinkResponse
	if err := json.Unmarshal(resp.Data, &data.Data); err != nil {
		return quarkFileLink{}, err
	}
	if len(data.Data) == 0 || strings.TrimSpace(data.Data[0].FileURL) == "" {
		return quarkFileLink{}, errors.New("获取播放链接失败")
	}
	link := quarkFileLink{
		URL:  strings.TrimSpace(data.Data[0].FileURL),
		Size: data.Data[0].Size,
	}
	cacheFileLink(fid, link, now)
	return link, nil
}

func (c *quarkClient) openDownloadStream(ctx context.Context, downloadURL, rangeHeader string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, downloadURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Referer", quarkDriveReferer)
	req.Header.Set("User-Agent", quarkDriveUserAgent)
	if strings.TrimSpace(c.cookie) != "" {
		req.Header.Set("Cookie", c.cookie)
	}
	if strings.TrimSpace(rangeHeader) != "" {
		req.Header.Set("Range", rangeHeader)
	}

	resp, err := c.transferClient().Do(req)
	if err != nil {
		return nil, err
	}
	c.syncCookieFromResponse(resp)
	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusPartialContent {
		return resp, nil
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	msg := strings.TrimSpace(string(body))
	if msg == "" {
		msg = resp.Status
	}
	return nil, errors.New(msg)
}

func (c *quarkClient) uploadMultipartFile(ctx context.Context, parentFid string, fileHeader *multipart.FileHeader, overrideName string) error {
	if fileHeader == nil {
		return errors.New("文件不能为空")
	}
	src, err := fileHeader.Open()
	if err != nil {
		return err
	}
	defer src.Close()

	name := strings.TrimSpace(overrideName)
	if name == "" {
		name = strings.TrimSpace(fileHeader.Filename)
	}
	if name == "" {
		return errors.New("文件名不能为空")
	}

	mimeType := strings.TrimSpace(fileHeader.Header.Get("Content-Type"))
	if mimeType == "" {
		mimeType = mime.TypeByExtension(path.Ext(name))
	}
	if mimeType == "" {
		mimeType = "application/octet-stream"
	}

	md5Hash := md5.New()
	sha1Hash := sha1.New()
	if _, err := io.Copy(io.MultiWriter(md5Hash, sha1Hash), src); err != nil {
		return err
	}
	if _, err := src.Seek(0, io.SeekStart); err != nil {
		return err
	}

	md5Str := hex.EncodeToString(md5Hash.Sum(nil))
	sha1Str := hex.EncodeToString(sha1Hash.Sum(nil))

	pre, err := c.uploadPre(ctx, name, mimeType, fileHeader.Size, parentFid)
	if err != nil {
		return err
	}
	finish, err := c.uploadHash(ctx, md5Str, sha1Str, pre.Data.TaskID)
	if err != nil {
		return err
	}
	if finish {
		return nil
	}

	partSize := int64(pre.Metadata.PartSize)
	if partSize <= 0 {
		partSize = 10 * 1024 * 1024
	}
	totalSize := fileHeader.Size
	partCount := int((totalSize + partSize - 1) / partSize)
	md5List := make([]string, 0, partCount)

	for partIndex := 0; partIndex < partCount; partIndex++ {
		offset := int64(partIndex) * partSize
		size := partSize
		if remain := totalSize - offset; remain < size {
			size = remain
		}
		section := io.NewSectionReader(src, offset, size)
		etag, err := c.uploadPart(ctx, pre, mimeType, partIndex+1, section)
		if err != nil {
			return err
		}
		md5List = append(md5List, etag)
	}

	if err := c.uploadCommit(ctx, pre, md5List); err != nil {
		return err
	}
	return c.uploadFinish(ctx, pre)
}

func (c *quarkClient) uploadPre(ctx context.Context, fileName, mimeType string, size int64, parentFid string) (quarkUploadPreResponse, error) {
	resp, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/upload/pre", nil, map[string]any{
		"ccp_hash_update": true,
		"dir_name":        "",
		"file_name":       fileName,
		"format_type":     mimeType,
		"l_created_at":    time.Now().UnixMilli(),
		"l_updated_at":    time.Now().UnixMilli(),
		"pdir_fid":        parentFid,
		"size":            size,
	})
	if err != nil {
		return quarkUploadPreResponse{}, err
	}

	var result quarkUploadPreResponse
	if err := json.Unmarshal(resp.Data, &result.Data); err != nil {
		return quarkUploadPreResponse{}, err
	}
	if err := json.Unmarshal(resp.Metadata, &result.Metadata); err != nil && len(resp.Metadata) > 0 && string(resp.Metadata) != "null" {
		return quarkUploadPreResponse{}, err
	}
	if strings.TrimSpace(result.Data.TaskID) == "" {
		return quarkUploadPreResponse{}, errors.New("上传初始化失败: task_id 为空")
	}
	return result, nil
}

func (c *quarkClient) uploadHash(ctx context.Context, md5Value, sha1Value, taskID string) (bool, error) {
	resp, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/update/hash", nil, map[string]any{
		"md5":     md5Value,
		"sha1":    sha1Value,
		"task_id": taskID,
	})
	if err != nil {
		return false, err
	}

	var result quarkUploadHashResponse
	if err := json.Unmarshal(resp.Data, &result.Data); err != nil {
		return false, err
	}
	return result.Data.Finish, nil
}

func (c *quarkClient) uploadPart(ctx context.Context, pre quarkUploadPreResponse, mimeType string, partNumber int, content io.Reader) (string, error) {
	timeStr := time.Now().UTC().Format(http.TimeFormat)
	authMeta := fmt.Sprintf(`PUT

%s
%s
x-oss-date:%s
x-oss-user-agent:aliyun-sdk-js/6.6.1 Chrome 98.0.4758.80 on Windows 10 64-bit
/%s/%s?partNumber=%d&uploadId=%s`,
		mimeType, timeStr, timeStr, pre.Data.Bucket, pre.Data.ObjKey, partNumber, pre.Data.UploadID)

	resp, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/upload/auth", nil, map[string]any{
		"auth_info": pre.Data.AuthInfo,
		"auth_meta": authMeta,
		"task_id":   pre.Data.TaskID,
	})
	if err != nil {
		return "", err
	}

	var auth quarkUploadAuthResponse
	if err := json.Unmarshal(resp.Data, &auth.Data); err != nil {
		return "", err
	}
	if strings.TrimSpace(auth.Data.AuthKey) == "" {
		return "", errors.New("上传分片失败: auth_key 为空")
	}

	uploadHost := strings.TrimPrefix(pre.Data.UploadURL, "https://")
	uploadHost = strings.TrimPrefix(uploadHost, "http://")
	uploadURL := fmt.Sprintf("https://%s.%s/%s", pre.Data.Bucket, uploadHost, pre.Data.ObjKey)

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, uploadURL, content)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", auth.Data.AuthKey)
	req.Header.Set("Content-Type", mimeType)
	req.Header.Set("Referer", quarkDriveReferer+"/")
	req.Header.Set("x-oss-date", timeStr)
	req.Header.Set("x-oss-user-agent", "aliyun-sdk-js/6.6.1 Chrome 98.0.4758.80 on Windows 10 64-bit")

	query := req.URL.Query()
	query.Set("partNumber", strconv.Itoa(partNumber))
	query.Set("uploadId", pre.Data.UploadID)
	req.URL.RawQuery = query.Encode()

	res, err := c.transferClient().Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(res.Body)
		return "", fmt.Errorf("上传分片失败(%d): %s", res.StatusCode, strings.TrimSpace(string(body)))
	}
	return res.Header.Get("Etag"), nil
}

func (c *quarkClient) uploadCommit(ctx context.Context, pre quarkUploadPreResponse, md5List []string) error {
	timeStr := time.Now().UTC().Format(http.TimeFormat)
	bodyBuilder := strings.Builder{}
	bodyBuilder.WriteString(`<?xml version="1.0" encoding="UTF-8"?>
<CompleteMultipartUpload>
`)
	for i, etag := range md5List {
		bodyBuilder.WriteString(fmt.Sprintf(`<Part>
<PartNumber>%d</PartNumber>
<ETag>%s</ETag>
</Part>
`, i+1, etag))
	}
	bodyBuilder.WriteString("</CompleteMultipartUpload>")
	body := bodyBuilder.String()

	checksum := md5.New()
	checksum.Write([]byte(body))
	contentMD5 := base64.StdEncoding.EncodeToString(checksum.Sum(nil))
	callbackBytes, err := json.Marshal(pre.Data.Callback)
	if err != nil {
		return err
	}
	callbackBase64 := base64.StdEncoding.EncodeToString(callbackBytes)

	authMeta := fmt.Sprintf(`POST
%s
application/xml
%s
x-oss-callback:%s
x-oss-date:%s
x-oss-user-agent:aliyun-sdk-js/6.6.1 Chrome 98.0.4758.80 on Windows 10 64-bit
/%s/%s?uploadId=%s`,
		contentMD5, timeStr, callbackBase64, timeStr, pre.Data.Bucket, pre.Data.ObjKey, pre.Data.UploadID)

	resp, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/upload/auth", nil, map[string]any{
		"auth_info": pre.Data.AuthInfo,
		"auth_meta": authMeta,
		"task_id":   pre.Data.TaskID,
	})
	if err != nil {
		return err
	}

	var auth quarkUploadAuthResponse
	if err := json.Unmarshal(resp.Data, &auth.Data); err != nil {
		return err
	}
	if strings.TrimSpace(auth.Data.AuthKey) == "" {
		return errors.New("提交上传失败: auth_key 为空")
	}

	uploadHost := strings.TrimPrefix(pre.Data.UploadURL, "https://")
	uploadHost = strings.TrimPrefix(uploadHost, "http://")
	uploadURL := fmt.Sprintf("https://%s.%s/%s", pre.Data.Bucket, uploadHost, pre.Data.ObjKey)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, uploadURL, strings.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", auth.Data.AuthKey)
	req.Header.Set("Content-MD5", contentMD5)
	req.Header.Set("Content-Type", "application/xml")
	req.Header.Set("Referer", quarkDriveReferer+"/")
	req.Header.Set("x-oss-callback", callbackBase64)
	req.Header.Set("x-oss-date", timeStr)
	req.Header.Set("x-oss-user-agent", "aliyun-sdk-js/6.6.1 Chrome 98.0.4758.80 on Windows 10 64-bit")

	query := req.URL.Query()
	query.Set("uploadId", pre.Data.UploadID)
	req.URL.RawQuery = query.Encode()

	res, err := c.transferClient().Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(res.Body)
		return fmt.Errorf("提交上传失败(%d): %s", res.StatusCode, strings.TrimSpace(string(body)))
	}
	return nil
}

func (c *quarkClient) uploadFinish(ctx context.Context, pre quarkUploadPreResponse) error {
	_, _, _, err := c.driveRequest(ctx, http.MethodPost, "/file/upload/finish", nil, map[string]any{
		"obj_key": pre.Data.ObjKey,
		"task_id": pre.Data.TaskID,
	})
	if err != nil {
		return err
	}
	time.Sleep(time.Second)
	return nil
}
