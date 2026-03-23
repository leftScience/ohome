package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type quarkSaveTask struct {
	ID               uint
	TaskName         string
	ShareURL         string
	SavePath         string
	RenameTopLevelTo string
}

type quarkSaveResult struct {
	Status     string
	Message    string
	SavedCount int
}

type quarkClient struct {
	httpClient    *http.Client
	cookie        string
	mparam        map[string]string
	persistCookie bool
	driveBaseURL  string
}

const (
	quarkBasePC    = "https://drive-pc.quark.cn"
	quarkBaseApp   = "https://drive-m.quark.cn"
	quarkUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) quark-cloud-drive/3.14.2 Chrome/112.0.5615.165 Electron/24.1.3.8 Safari/537.36 Channel/pckk_other_ch"
)

func newQuarkClient(cookie string) *quarkClient {
	return &quarkClient{
		httpClient:   &http.Client{Timeout: quarkAPITimeout},
		cookie:       strings.TrimSpace(cookie),
		mparam:       matchMParamFromCookie(cookie),
		driveBaseURL: quarkDefaultDriveBaseURL,
	}
}

func matchMParamFromCookie(cookie string) map[string]string {
	kv := map[string]string{}
	for _, part := range strings.Split(cookie, ";") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		k, v, ok := strings.Cut(part, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.TrimSpace(v)
		if k == "" || v == "" {
			continue
		}
		kv[k] = v
	}

	kps, ok1 := kv["kps"]
	sign, ok2 := kv["sign"]
	vcode, ok3 := kv["vcode"]
	if !ok1 || !ok2 || !ok3 {
		return map[string]string{}
	}

	return map[string]string{
		"kps":   strings.ReplaceAll(kps, "%25", "%"),
		"sign":  strings.ReplaceAll(sign, "%25", "%"),
		"vcode": strings.ReplaceAll(vcode, "%25", "%"),
	}
}

type quarkAPIResponse struct {
	Status   int             `json:"status"`
	Code     int             `json:"code"`
	Message  string          `json:"message"`
	Data     json.RawMessage `json:"data"`
	Metadata json.RawMessage `json:"metadata"`
}

func (r *quarkAPIResponse) UnmarshalJSON(b []byte) error {
	type raw struct {
		Status   any             `json:"status"`
		Code     any             `json:"code"`
		Message  string          `json:"message"`
		Data     json.RawMessage `json:"data"`
		Metadata json.RawMessage `json:"metadata"`
	}
	var rr raw
	if err := json.Unmarshal(b, &rr); err != nil {
		return err
	}
	r.Status = toInt(rr.Status)
	r.Code = toInt(rr.Code)
	r.Message = rr.Message
	r.Data = rr.Data
	r.Metadata = rr.Metadata
	return nil
}

func toInt(v any) int {
	switch x := v.(type) {
	case nil:
		return 0
	case int:
		return x
	case int64:
		return int(x)
	case float64:
		return int(x)
	case json.Number:
		i, _ := x.Int64()
		return int(i)
	case string:
		i, _ := strconv.Atoi(strings.TrimSpace(x))
		return i
	default:
		i, _ := strconv.Atoi(strings.TrimSpace(fmt.Sprint(x)))
		return i
	}
}

func (c *quarkClient) initAccount(ctx context.Context) error {
	u := "https://pan.quark.cn/account/info"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return err
	}
	req.Header.Set("user-agent", quarkUserAgent)
	req.Header.Set("cookie", c.cookie)
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	c.syncCookieFromResponse(resp)
	b, _ := io.ReadAll(resp.Body)
	var r quarkAPIResponse
	if err := json.Unmarshal(b, &r); err != nil {
		return fmt.Errorf("解析 quark account/info 失败: %w", err)
	}
	if r.Code != 0 {
		return fmt.Errorf("quark cookie 无效: %s", r.Message)
	}
	return nil
}

func (c *quarkClient) saveFromShare(ctx context.Context, task quarkSaveTask) (quarkSaveResult, error) {
	pwdID, passcode, pdirFid, err := extractShareParams(task.ShareURL)
	if err != nil {
		return quarkSaveResult{Status: "fail", Message: err.Error()}, err
	}

	stoken, err := c.getStoken(ctx, pwdID, passcode)
	if err != nil {
		return quarkSaveResult{Status: "fail", Message: err.Error()}, err
	}

	saveRootPath := buildQuarkSavePath(task.SavePath)
	saveRootFid, err := c.ensurePathFid(ctx, saveRootPath)
	if err != nil {
		return quarkSaveResult{Status: "fail", Message: err.Error()}, err
	}

	var topLevelBefore []quarkDirItem
	renameTarget := strings.TrimSpace(task.RenameTopLevelTo)
	if renameTarget != "" {
		topLevelBefore, err = c.listDirAll(ctx, saveRootFid)
		if err != nil {
			return quarkSaveResult{Status: "fail", Message: err.Error()}, err
		}
	}

	saved, err := c.syncShareDir(ctx, pwdID, stoken, pdirFid, saveRootPath, saveRootFid)
	if err != nil {
		return quarkSaveResult{Status: "fail", Message: err.Error()}, err
	}
	if saved == 0 {
		return quarkSaveResult{Status: "ok", Message: "无新增文件", SavedCount: 0}, nil
	}

	message := fmt.Sprintf("新增转存 %d 项", saved)
	if renameTarget != "" {
		renamedTo, renamed, renameErr := c.tryRenameTransferredTopLevelEntry(
			ctx,
			saveRootFid,
			topLevelBefore,
			renameTarget,
		)
		switch {
		case renameErr != nil:
			message = fmt.Sprintf("%s，自动重命名失败：%s", message, strings.TrimSpace(renameErr.Error()))
		case renamed && strings.TrimSpace(renamedTo) != "":
			message = fmt.Sprintf("%s，已重命名为 %s", message, strings.TrimSpace(renamedTo))
		}
	}

	return quarkSaveResult{Status: "ok", Message: message, SavedCount: saved}, nil
}

func buildQuarkSavePath(storePath string) string {
	p := strings.TrimSpace(storePath)
	p = normalizeQuarkPath(p)
	if p == "/" || p == "" {
		return "/"
	}
	return normalizeQuarkPath(strings.TrimLeft(p, "/"))
}

type quarkShareFile struct {
	Fid           string `json:"fid"`
	ShareFidToken string `json:"share_fid_token"`
	FileName      string `json:"file_name"`
	Dir           bool   `json:"dir"`
}

func extractShareParams(raw string) (pwdID string, passcode string, pdirFid string, err error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", "", "", errors.New("分享链接为空")
	}

	// 允许粘贴多行：优先选取包含关键字段的一行
	if strings.Contains(raw, "\n") || strings.Contains(raw, "\r") {
		for _, line := range strings.FieldsFunc(raw, func(r rune) bool { return r == '\n' || r == '\r' }) {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			if strings.Contains(line, "/s/") || strings.Contains(line, "surl=") || strings.Contains(line, "pwd_id=") {
				raw = line
				break
			}
		}
	}

	// 1) 标准格式：.../s/<pwd_id>
	if m := regexp.MustCompile(`/s/([a-zA-Z0-9_]+)`).FindStringSubmatch(raw); len(m) == 2 {
		pwdID = m[1]
	} else {
		// 2) query 参数：?pwd_id=<pwd_id> / ?surl=<pwd_id>
		if u, parseErr := url.Parse(raw); parseErr == nil {
			q := u.Query()
			if v := strings.TrimSpace(q.Get("pwd_id")); v != "" {
				pwdID = v
			} else if v := strings.TrimSpace(q.Get("surl")); v != "" {
				pwdID = v
			}
		}
		// 3) 仅粘贴了 id 本身
		if pwdID == "" && regexp.MustCompile(`^[a-zA-Z0-9_]+$`).MatchString(raw) {
			pwdID = raw
		}
		if pwdID == "" {
			return "", "", "", errors.New("无法从分享链接解析 pwd_id（请粘贴包含 /s/<id> 的链接）")
		}
	}

	// 提取码：优先 query 中的 pwd / passcode，其次文本中的“提取码”
	if u, parseErr := url.Parse(raw); parseErr == nil {
		q := u.Query()
		if v := strings.TrimSpace(q.Get("pwd")); v != "" {
			passcode = v
		} else if v := strings.TrimSpace(q.Get("passcode")); v != "" {
			passcode = v
		}
		if passcode == "" && u.Fragment != "" {
			if fq, ok := parseFragmentQuery(u.Fragment); ok {
				if v := strings.TrimSpace(fq.Get("pwd")); v != "" {
					passcode = v
				} else if v := strings.TrimSpace(fq.Get("passcode")); v != "" {
					passcode = v
				}
			}
		}
	}
	if passcode == "" {
		if m := regexp.MustCompile(`(?i)\bpwd=([a-zA-Z0-9_]+)`).FindStringSubmatch(raw); len(m) == 2 {
			passcode = m[1]
		} else if m := regexp.MustCompile(`提取码[:：]?\s*([0-9a-zA-Z]{4,8})`).FindStringSubmatch(raw); len(m) == 2 {
			passcode = m[1]
		}
	}

	// 子目录：优先 query / fragment 中的 pdir_fid / fid
	pdirFid = "0"
	if u, parseErr := url.Parse(raw); parseErr == nil {
		q := u.Query()
		if v := strings.TrimSpace(q.Get("pdir_fid")); v != "" {
			pdirFid = v
		} else if v := strings.TrimSpace(q.Get("fid")); v != "" && isLikelyFid(v) {
			pdirFid = v
		}
		if pdirFid == "0" && u.Fragment != "" {
			if fq, ok := parseFragmentQuery(u.Fragment); ok {
				if v := strings.TrimSpace(fq.Get("pdir_fid")); v != "" {
					pdirFid = v
				} else if v := strings.TrimSpace(fq.Get("fid")); v != "" && isLikelyFid(v) {
					pdirFid = v
				}
			}
		}
	}

	// 兼容 path 中出现的 32 位 fid：取最后一个
	if pdirFid == "0" {
		matches := regexp.MustCompile(`/([a-zA-Z0-9]{32})-?([^/]+)?`).FindAllStringSubmatch(raw, -1)
		if len(matches) > 0 && len(matches[len(matches)-1]) >= 2 {
			pdirFid = matches[len(matches)-1][1]
		}
	}

	return pwdID, passcode, pdirFid, nil
}

func parseFragmentQuery(fragment string) (url.Values, bool) {
	i := strings.Index(fragment, "?")
	if i < 0 || i+1 >= len(fragment) {
		return nil, false
	}
	v, err := url.ParseQuery(fragment[i+1:])
	if err != nil {
		return nil, false
	}
	return v, true
}

func isLikelyFid(s string) bool {
	if len(s) != 32 {
		return false
	}
	for _, r := range s {
		if (r >= '0' && r <= '9') || (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') {
			continue
		}
		return false
	}
	return true
}

func normalizeQuarkPath(p string) string {
	p = strings.TrimSpace(p)
	if p == "" {
		return "/"
	}
	if !strings.HasPrefix(p, "/") {
		p = "/" + p
	}
	p = regexp.MustCompile(`/+`).ReplaceAllString(p, "/")
	return p
}

func (c *quarkClient) doJSON(ctx context.Context, method string, rawURL string, query map[string]string, payload any, useCookie bool) (quarkAPIResponse, []byte, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return quarkAPIResponse{}, nil, err
	}
	q := u.Query()
	for k, v := range query {
		q.Set(k, v)
	}

	headers := map[string]string{
		"user-agent":   quarkUserAgent,
		"content-type": "application/json",
	}
	if useCookie {
		headers["cookie"] = c.cookie
	}

	// quark-auto-save 兼容逻辑：如果具备移动端 mparam 且请求 share 接口，则走 mobile base 并追加参数（不带 cookie）
	if len(c.mparam) > 0 && strings.Contains(u.Path, "/share/") && strings.HasPrefix(rawURL, quarkBasePC) {
		u.Scheme = "https"
		u.Host = strings.TrimPrefix(quarkBaseApp, "https://")
		q.Set("fr", "android")
		q.Set("pr", "ucpro")
		q.Set("kps", c.mparam["kps"])
		q.Set("sign", c.mparam["sign"])
		q.Set("vcode", c.mparam["vcode"])
		q.Set("app", "clouddrive")
		q.Set("kkkk", "1")
		delete(headers, "cookie")
		useCookie = false
	}

	u.RawQuery = q.Encode()

	var body io.Reader
	if payload != nil {
		b, err := json.Marshal(payload)
		if err != nil {
			return quarkAPIResponse{}, nil, err
		}
		body = bytes.NewReader(b)
	}

	req, err := http.NewRequestWithContext(ctx, method, u.String(), body)
	if err != nil {
		return quarkAPIResponse{}, nil, err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return quarkAPIResponse{Status: 500, Code: 1, Message: "request error"}, nil, err
	}
	defer resp.Body.Close()
	c.syncCookieFromResponse(resp)
	b, _ := io.ReadAll(resp.Body)

	var r quarkAPIResponse
	if err := json.Unmarshal(b, &r); err != nil {
		return quarkAPIResponse{Status: resp.StatusCode, Code: 1, Message: "json decode error"}, b, err
	}
	if r.Status == 0 {
		r.Status = resp.StatusCode
	}
	return r, b, nil
}

func (c *quarkClient) getStoken(ctx context.Context, pwdID, passcode string) (string, error) {
	resp, _, err := c.doJSON(ctx, http.MethodPost, quarkBasePC+"/1/clouddrive/share/sharepage/token", map[string]string{
		"pr": "ucpro",
		"fr": "pc",
	}, map[string]any{
		"pwd_id":   pwdID,
		"passcode": passcode,
	}, true)
	if err != nil {
		return "", err
	}
	if resp.Code != 0 {
		return "", fmt.Errorf("获取 stoken 失败: %s", resp.Message)
	}
	var data struct {
		Stoken string `json:"stoken"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		return "", err
	}
	if data.Stoken == "" {
		return "", errors.New("获取 stoken 失败: stoken 为空")
	}
	return data.Stoken, nil
}

func (c *quarkClient) getShareDetailAll(ctx context.Context, pwdID, stoken, pdirFid string) ([]quarkShareFile, error) {
	page := 1
	var all []quarkShareFile
	for {
		resp, _, err := c.doJSON(ctx, http.MethodGet, quarkBasePC+"/1/clouddrive/share/sharepage/detail", map[string]string{
			"pr":                    "ucpro",
			"fr":                    "pc",
			"pwd_id":                pwdID,
			"stoken":                stoken,
			"pdir_fid":              pdirFid,
			"force":                 "0",
			"_page":                 fmt.Sprintf("%d", page),
			"_size":                 "50",
			"_fetch_banner":         "0",
			"_fetch_share":          "0",
			"_fetch_total":          "1",
			"_sort":                 "file_type:asc,updated_at:desc",
			"ver":                   "2",
			"fetch_share_full_path": "0",
		}, nil, true)
		if err != nil {
			return nil, err
		}
		if resp.Code != 0 {
			return nil, fmt.Errorf("获取分享文件列表失败: %s", resp.Message)
		}
		var data struct {
			List []quarkShareFile `json:"list"`
		}
		if err := json.Unmarshal(resp.Data, &data); err != nil {
			return nil, err
		}
		if len(data.List) == 0 {
			break
		}
		all = append(all, data.List...)
		page++
		if page > 200 {
			break
		}
	}
	return all, nil
}

func (c *quarkClient) validateShareAccess(ctx context.Context, pwdID, stoken, pdirFid string) error {
	resp, _, err := c.doJSON(ctx, http.MethodGet, quarkBasePC+"/1/clouddrive/share/sharepage/detail", map[string]string{
		"pr":                    "ucpro",
		"fr":                    "pc",
		"pwd_id":                pwdID,
		"stoken":                stoken,
		"pdir_fid":              pdirFid,
		"force":                 "0",
		"_page":                 "1",
		"_size":                 "1",
		"_fetch_banner":         "0",
		"_fetch_share":          "0",
		"_fetch_total":          "0",
		"_sort":                 "file_type:asc,updated_at:desc",
		"ver":                   "2",
		"fetch_share_full_path": "0",
	}, nil, true)
	if err != nil {
		return err
	}
	if resp.Code != 0 {
		return fmt.Errorf("获取分享文件列表失败: %s", resp.Message)
	}
	return nil
}

func (c *quarkClient) ensurePathFid(ctx context.Context, path string) (string, error) {
	fid, err := c.getFidByPath(ctx, path)
	if err == nil && fid != "" {
		return fid, nil
	}
	resp, _, err := c.doJSON(ctx, http.MethodPost, quarkBasePC+"/1/clouddrive/file", map[string]string{
		"pr":           "ucpro",
		"fr":           "pc",
		"uc_param_str": "",
	}, map[string]any{
		"pdir_fid":      "0",
		"file_name":     "",
		"dir_path":      path,
		"dir_init_lock": false,
	}, true)
	if err != nil {
		return "", err
	}
	if resp.Code != 0 {
		return "", fmt.Errorf("创建目录失败(%s): %s", path, resp.Message)
	}
	var data struct {
		Fid string `json:"fid"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		return "", err
	}
	if data.Fid == "" {
		return "", errors.New("创建目录失败: fid 为空")
	}
	return data.Fid, nil
}

func (c *quarkClient) getFidByPath(ctx context.Context, path string) (string, error) {
	resp, _, err := c.doJSON(ctx, http.MethodGet, quarkBasePC+"/1/clouddrive/file/search", map[string]string{
		"pr":                   "ucpro",
		"fr":                   "pc",
		"uc_param_str":         "",
		"query":                path,
		"page":                 "1",
		"size":                 "1",
		"recursion":            "1",
		"exactly":              "1",
		"fetch_full_path":      "0",
		"fetch_total":          "0",
		"fetch_sub_dirs":       "0",
		"fetch_risk_file_name": "1",
	}, nil, true)
	if err != nil {
		return "", err
	}
	if resp.Code != 0 {
		return "", fmt.Errorf("获取目录 fid 失败(%s): %s", path, resp.Message)
	}
	var data []struct {
		Fid string `json:"fid"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		return "", err
	}
	if len(data) == 0 {
		return "", errors.New("not found")
	}
	return data[0].Fid, nil
}

type quarkDirItem struct {
	Fid      string `json:"fid"`
	FileName string `json:"file_name"`
	Dir      bool   `json:"dir"`
}

func (c *quarkClient) listDirAll(ctx context.Context, pdirFid string) ([]quarkDirItem, error) {
	page := 1
	var all []quarkDirItem
	for {
		resp, _, err := c.doJSON(ctx, http.MethodGet, quarkBasePC+"/1/clouddrive/file/sort", map[string]string{
			"pr":                   "ucpro",
			"fr":                   "pc",
			"uc_param_str":         "",
			"pdir_fid":             pdirFid,
			"_page":                fmt.Sprintf("%d", page),
			"_size":                "50",
			"_fetch_total":         "1",
			"_fetch_sub_dirs":      "0",
			"_sort":                "file_type:asc,updated_at:desc",
			"_fetch_full_path":     "0",
			"fetch_all_file":       "1",
			"fetch_risk_file_name": "1",
		}, nil, true)
		if err != nil {
			return nil, err
		}
		if resp.Code != 0 {
			return nil, fmt.Errorf("列目录失败: %s", resp.Message)
		}
		var data struct {
			List []quarkDirItem `json:"list"`
		}
		if err := json.Unmarshal(resp.Data, &data); err != nil {
			return nil, err
		}
		if len(data.List) == 0 {
			break
		}
		all = append(all, data.List...)
		page++
		if page > 200 {
			break
		}
	}
	return all, nil
}

func (c *quarkClient) validateDirAccess(ctx context.Context, pdirFid string) error {
	resp, _, err := c.doJSON(ctx, http.MethodGet, quarkBasePC+"/1/clouddrive/file/sort", map[string]string{
		"pr":                   "ucpro",
		"fr":                   "pc",
		"uc_param_str":         "",
		"pdir_fid":             pdirFid,
		"_page":                "1",
		"_size":                "1",
		"_fetch_total":         "0",
		"_fetch_sub_dirs":      "0",
		"_sort":                "file_type:asc,updated_at:desc",
		"_fetch_full_path":     "0",
		"fetch_all_file":       "1",
		"fetch_risk_file_name": "1",
	}, nil, true)
	if err != nil {
		return err
	}
	if resp.Code != 0 {
		return fmt.Errorf("列目录失败: %s", resp.Message)
	}
	return nil
}

func (c *quarkClient) syncShareDir(ctx context.Context, pwdID, stoken, shareDirFid, destPath, destFid string) (int, error) {
	shareFiles, err := c.getShareDetailAll(ctx, pwdID, stoken, shareDirFid)
	if err != nil {
		return 0, err
	}

	destItems, err := c.listDirAll(ctx, destFid)
	if err != nil {
		return 0, err
	}
	exists := map[string]quarkDirItem{}
	for _, it := range destItems {
		exists[it.FileName] = it
	}

	totalSaved := 0

	// 同级文件批量转存（已存在则跳过）
	var needSave []quarkShareFile
	for _, sf := range shareFiles {
		if sf.Dir {
			continue
		}
		if _, ok := exists[sf.FileName]; ok {
			continue
		}
		needSave = append(needSave, sf)
	}
	for i := 0; i < len(needSave); i += 50 {
		end := i + 50
		if end > len(needSave) {
			end = len(needSave)
		}
		taskID, err := c.saveFile(ctx, needSave[i:end], destFid, pwdID, stoken)
		if err != nil {
			return totalSaved, err
		}
		if err := c.waitTaskDone(ctx, taskID); err != nil {
			return totalSaved, err
		}
		totalSaved += end - i
	}

	// 子目录：保证目录存在并递归同步
	for _, sf := range shareFiles {
		if !sf.Dir {
			continue
		}
		subPath := normalizeQuarkPath(destPath + "/" + sf.FileName)

		subFid := ""
		if it, ok := exists[sf.FileName]; ok && it.Dir && it.Fid != "" {
			subFid = it.Fid
		} else {
			fid, err := c.ensurePathFid(ctx, subPath)
			if err != nil {
				return totalSaved, err
			}
			subFid = fid
		}

		subSaved, err := c.syncShareDir(ctx, pwdID, stoken, sf.Fid, subPath, subFid)
		if err != nil {
			return totalSaved, err
		}
		totalSaved += subSaved
	}

	return totalSaved, nil
}

func (c *quarkClient) tryRenameTransferredTopLevelEntry(
	ctx context.Context,
	destFid string,
	beforeItems []quarkDirItem,
	desiredName string,
) (string, bool, error) {
	desiredName = normalizeQuarkTransferRenameName(desiredName)
	if desiredName == "" {
		return "", false, nil
	}

	afterItems, err := c.listDirAll(ctx, destFid)
	if err != nil {
		return "", false, err
	}

	newItems := diffNewQuarkDirItems(beforeItems, afterItems)
	candidate, ok := pickQuarkRenameCandidate(newItems)
	if !ok {
		return "", false, nil
	}

	targetName := buildQuarkTransferRenameTarget(candidate, desiredName)
	targetName = dedupeQuarkTransferRenameTarget(targetName, afterItems, candidate.FileName)
	if targetName == "" || strings.EqualFold(strings.TrimSpace(targetName), strings.TrimSpace(candidate.FileName)) {
		return "", false, nil
	}

	if err := c.rename(ctx, candidate.Fid, targetName); err != nil {
		return "", false, err
	}
	return targetName, true, nil
}

func diffNewQuarkDirItems(beforeItems, afterItems []quarkDirItem) []quarkDirItem {
	beforeByFid := make(map[string]struct{}, len(beforeItems))
	beforeByName := make(map[string]struct{}, len(beforeItems))
	for _, item := range beforeItems {
		name := strings.TrimSpace(item.FileName)
		if name != "" {
			beforeByName[strings.ToLower(name)] = struct{}{}
		}
		fid := strings.TrimSpace(item.Fid)
		if fid != "" {
			beforeByFid[fid] = struct{}{}
		}
	}

	newItems := make([]quarkDirItem, 0, len(afterItems))
	for _, item := range afterItems {
		name := strings.TrimSpace(item.FileName)
		fid := strings.TrimSpace(item.Fid)
		if fid != "" {
			if _, ok := beforeByFid[fid]; ok {
				continue
			}
		}
		if name != "" {
			if _, ok := beforeByName[strings.ToLower(name)]; ok {
				continue
			}
		}
		newItems = append(newItems, item)
	}
	return newItems
}

func pickQuarkRenameCandidate(items []quarkDirItem) (quarkDirItem, bool) {
	if len(items) == 1 {
		return items[0], true
	}

	var dirCandidate quarkDirItem
	dirCount := 0
	for _, item := range items {
		if item.Dir {
			dirCandidate = item
			dirCount++
		}
	}
	if dirCount == 1 {
		return dirCandidate, true
	}

	return quarkDirItem{}, false
}

func buildQuarkTransferRenameTarget(item quarkDirItem, desiredName string) string {
	name := normalizeQuarkTransferRenameName(desiredName)
	if name == "" {
		return ""
	}
	if item.Dir {
		return name
	}

	ext := strings.TrimSpace(path.Ext(strings.TrimSpace(item.FileName)))
	if ext == "" {
		return name
	}
	if len(name) >= len(ext) && strings.EqualFold(name[len(name)-len(ext):], ext) {
		return name
	}
	return name + ext
}

func dedupeQuarkTransferRenameTarget(targetName string, siblingItems []quarkDirItem, selfName string) string {
	targetName = strings.TrimSpace(targetName)
	if targetName == "" {
		return ""
	}

	usedNames := make(map[string]struct{}, len(siblingItems))
	selfName = strings.TrimSpace(selfName)
	for _, item := range siblingItems {
		name := strings.TrimSpace(item.FileName)
		if name == "" || strings.EqualFold(name, selfName) {
			continue
		}
		usedNames[strings.ToLower(name)] = struct{}{}
	}

	if _, exists := usedNames[strings.ToLower(targetName)]; !exists {
		return targetName
	}

	ext := path.Ext(targetName)
	base := strings.TrimSuffix(targetName, ext)
	if strings.TrimSpace(base) == "" {
		base = "资源"
	}

	for i := 2; i <= 999; i++ {
		candidate := fmt.Sprintf("%s (%d)%s", base, i, ext)
		if _, exists := usedNames[strings.ToLower(candidate)]; !exists {
			return candidate
		}
	}

	return fmt.Sprintf("%s_%d%s", base, time.Now().Unix(), ext)
}

func normalizeQuarkTransferRenameName(name string) string {
	name = strings.NewReplacer(
		"\r", " ",
		"\n", " ",
		"\t", " ",
		"/", "／",
		"\\", "／",
		":", "：",
		"*", "＊",
		"?", "？",
		"\"", "”",
		"<", "＜",
		">", "＞",
		"|", "｜",
	).Replace(strings.TrimSpace(name))
	name = strings.Join(strings.Fields(name), " ")
	name = strings.Trim(name, ". ")
	return strings.TrimSpace(name)
}

func (c *quarkClient) saveFile(ctx context.Context, files []quarkShareFile, toPdirFid, pwdID, stoken string) (string, error) {
	var fidList []string
	var fidTokenList []string
	for _, f := range files {
		fidList = append(fidList, f.Fid)
		fidTokenList = append(fidTokenList, f.ShareFidToken)
	}
	resp, _, err := c.doJSON(ctx, http.MethodPost, quarkBasePC+"/1/clouddrive/share/sharepage/save", map[string]string{
		"pr":           "ucpro",
		"fr":           "pc",
		"uc_param_str": "",
		"app":          "clouddrive",
		"__dt":         fmt.Sprintf("%d", (rand.Intn(4)+1)*60*1000),
		"__t":          fmt.Sprintf("%d", time.Now().Unix()),
	}, map[string]any{
		"fid_list":       fidList,
		"fid_token_list": fidTokenList,
		"to_pdir_fid":    toPdirFid,
		"pwd_id":         pwdID,
		"stoken":         stoken,
		"pdir_fid":       "0",
		"scene":          "link",
	}, true)
	if err != nil {
		return "", err
	}
	if resp.Code != 0 {
		return "", fmt.Errorf("转存失败: %s", resp.Message)
	}
	var data struct {
		TaskID string `json:"task_id"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		return "", err
	}
	if data.TaskID == "" {
		return "", errors.New("转存失败: task_id 为空")
	}
	return data.TaskID, nil
}

func (c *quarkClient) waitTaskDone(ctx context.Context, taskID string) error {
	retry := 0
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
		resp, _, err := c.doJSON(ctx, http.MethodGet, quarkBasePC+"/1/clouddrive/task", map[string]string{
			"pr":           "ucpro",
			"fr":           "pc",
			"uc_param_str": "",
			"task_id":      taskID,
			"retry_index":  fmt.Sprintf("%d", retry),
			"__dt":         fmt.Sprintf("%d", (rand.Intn(4)+1)*60*1000),
			"__t":          fmt.Sprintf("%d", time.Now().Unix()),
		}, nil, true)
		if err != nil {
			return err
		}
		if resp.Status != 200 {
			return fmt.Errorf("查询任务状态失败: %s", resp.Message)
		}
		var data struct {
			Status    int    `json:"status"`
			TaskTitle string `json:"task_title"`
		}
		if err := json.Unmarshal(resp.Data, &data); err != nil {
			return err
		}
		switch data.Status {
		case 2:
			return nil
		case 3:
			if data.TaskTitle != "" {
				return fmt.Errorf("任务失败: %s", data.TaskTitle)
			}
			return errors.New("任务失败")
		default:
			retry++
			time.Sleep(2 * time.Second)
		}
	}
}
