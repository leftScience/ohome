package service

import (
	"context"
	"crypto/md5"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"ohome/model"
	"ohome/service/dto"
	"strings"
	"sync"
	"time"

	"gorm.io/gorm"
)

const (
	quarkTVRefreshTokenConfigKey = "quark_tv_refresh_token"
	quarkTVDeviceIDConfigKey     = "quark_tv_device_id"
	quarkTVQueryTokenConfigKey   = "quark_tv_query_token"

	quarkTVAPIBaseURL  = "https://open-api-drive.quark.cn"
	quarkTVCodeAPIBase = "http://api.extscreen.com/quarkdrive"
	quarkTVClientID    = "d3194e61504e493eb6222857bccfed94"
	quarkTVSignKey     = "kw2dvtd7p4t3pjl2d9ed9yc8yej8kw2d"
	quarkTVAppVersion  = "1.8.2.2"
	quarkTVChannel     = "GENERAL"
	quarkTVUserAgent   = "Mozilla/5.0 (Linux; U; Android 13; zh-cn; M2004J7AC Build/UKQ1.231108.001) AppleWebKit/533.1 (KHTML, like Gecko) Mobile Safari/533.1"

	quarkTVDeviceBrand  = "Xiaomi"
	quarkTVPlatform     = "tv"
	quarkTVDeviceName   = "M2004J7AC"
	quarkTVDeviceModel  = "M2004J7AC"
	quarkTVBuildDevice  = "M2004J7AC"
	quarkTVBuildProduct = "M2004J7AC"
	quarkTVDeviceGPU    = "Adreno (TM) 550"
	quarkTVActivityRect = "{}"

	quarkTVTokenRefreshBuffer = time.Minute
	quarkTVHTTPTimeout        = 20 * time.Second
)

type QuarkTVLoginService struct {
	BaseService
}

type QuarkTVLoginStatus struct {
	Configured bool       `json:"configured"`
	Pending    bool       `json:"pending"`
	UpdatedAt  *time.Time `json:"updatedAt,omitempty"`
}

type QuarkTVLoginStartResult struct {
	QrData  string `json:"qrData"`
	Pending bool   `json:"pending"`
}

type QuarkTVLoginPollResult struct {
	Status     string     `json:"status"`
	Message    string     `json:"message,omitempty"`
	Configured bool       `json:"configured"`
	Pending    bool       `json:"pending"`
	UpdatedAt  *time.Time `json:"updatedAt,omitempty"`
}

type quarkTVConfigSnapshot struct {
	RefreshToken    model.Config
	DeviceID        model.Config
	QueryToken      model.Config
	HasRefreshToken bool
	HasDeviceID     bool
	HasQueryToken   bool
}

type quarkTVClient struct {
	httpClient   *http.Client
	accessToken  string
	refreshToken string
	deviceID     string
}

type quarkTVResponseEnvelope struct {
	Status    int    `json:"status"`
	ReqID     string `json:"req_id"`
	Errno     int    `json:"errno"`
	ErrorInfo string `json:"error_info"`
}

type quarkTVAuthorizeResponse struct {
	quarkTVResponseEnvelope
	QrData     string `json:"qr_data"`
	QueryToken string `json:"query_token"`
}

type quarkTVCodeResponse struct {
	quarkTVResponseEnvelope
	Code string `json:"code"`
}

type quarkTVTokenResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Status       int    `json:"status"`
		Errno        int    `json:"errno"`
		ErrorInfo    string `json:"error_info"`
		ReqID        string `json:"req_id"`
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		ExpiresIn    int    `json:"expires_in"`
		Scope        string `json:"scope"`
	} `json:"data"`
}

type quarkTVStreamingResponse struct {
	quarkTVResponseEnvelope
	Data struct {
		DefaultResolution string `json:"default_resolution"`
		VideoInfo         []struct {
			Resolution  string  `json:"resolution"`
			Accessable  int     `json:"accessable"`
			TransStatus string  `json:"trans_status"`
			Duration    int     `json:"duration"`
			Size        int64   `json:"size"`
			Format      string  `json:"format"`
			Width       int     `json:"width"`
			Height      int     `json:"height"`
			URL         string  `json:"url"`
			Bitrate     float64 `json:"bitrate"`
		} `json:"video_info"`
	} `json:"data"`
}

var quarkTVAccessTokenCache = struct {
	mu           sync.RWMutex
	refreshToken string
	accessToken  string
	expiresAt    time.Time
}{}

func (s *QuarkTVLoginService) GetStatus(userID uint) (QuarkTVLoginStatus, error) {
	snapshot, err := loadQuarkTVConfigSnapshotForUser(userID)
	if err != nil {
		return QuarkTVLoginStatus{}, err
	}
	return buildQuarkTVLoginStatus(snapshot), nil
}

func (s *QuarkTVLoginService) StartLogin(ctx context.Context, userID uint) (QuarkTVLoginStartResult, error) {
	snapshot, err := loadQuarkTVConfigSnapshotForUser(userID)
	if err != nil {
		return QuarkTVLoginStartResult{}, err
	}

	deviceID := snapshot.DeviceIDValue()
	if deviceID == "" {
		deviceID = generateQuarkTVDeviceID()
	}

	client := newQuarkTVClient(snapshot)
	client.deviceID = deviceID

	qrData, queryToken, err := client.getLoginQRCode(ctx)
	if err != nil {
		return QuarkTVLoginStartResult{}, err
	}
	if strings.TrimSpace(qrData) == "" || strings.TrimSpace(queryToken) == "" {
		return QuarkTVLoginStartResult{}, errors.New("夸克TV登录二维码生成失败")
	}

	if _, err := upsertQuarkTVConfigForUser(userID, quarkTVDeviceIDConfigKey, deviceID); err != nil {
		return QuarkTVLoginStartResult{}, err
	}
	if _, err := upsertQuarkTVConfigForUser(userID, quarkTVQueryTokenConfigKey, queryToken); err != nil {
		return QuarkTVLoginStartResult{}, err
	}

	return QuarkTVLoginStartResult{
		QrData:  strings.TrimSpace(qrData),
		Pending: true,
	}, nil
}

func (s *QuarkTVLoginService) PollLogin(ctx context.Context, userID uint) (QuarkTVLoginPollResult, error) {
	snapshot, err := loadQuarkTVConfigSnapshotForUser(userID)
	if err != nil {
		return QuarkTVLoginPollResult{}, err
	}

	queryToken := snapshot.QueryTokenValue()
	if queryToken == "" {
		return QuarkTVLoginPollResult{
			Status:     "error",
			Message:    "未找到待确认的夸克TV登录，请重新开始扫码",
			Configured: snapshot.RefreshTokenValue() != "",
			Pending:    false,
			UpdatedAt:  latestQuarkTVUpdatedAt(snapshot),
		}, nil
	}

	deviceID := snapshot.DeviceIDValue()
	if deviceID == "" {
		deviceID = generateQuarkTVDeviceID()
		if _, err := upsertQuarkTVConfigForUser(userID, quarkTVDeviceIDConfigKey, deviceID); err != nil {
			return QuarkTVLoginPollResult{}, err
		}
		snapshot.DeviceID.Value = deviceID
		snapshot.HasDeviceID = true
	}

	client := newQuarkTVClient(snapshot)
	client.deviceID = deviceID

	code, err := client.getLoginCode(ctx, queryToken)
	if err != nil {
		status := classifyQuarkTVPollError(err)
		if status == "expired" {
			if clearErr := deleteQuarkTVConfigByKeyForUser(userID, quarkTVQueryTokenConfigKey); clearErr != nil {
				return QuarkTVLoginPollResult{}, clearErr
			}
			snapshot.HasQueryToken = false
			snapshot.QueryToken = model.Config{}
		}
		return QuarkTVLoginPollResult{
			Status:     status,
			Message:    strings.TrimSpace(err.Error()),
			Configured: snapshot.RefreshTokenValue() != "",
			Pending:    status == "pending",
			UpdatedAt:  latestQuarkTVUpdatedAt(snapshot),
		}, nil
	}

	if strings.TrimSpace(code) == "" {
		return QuarkTVLoginPollResult{
			Status:     "pending",
			Message:    "请在夸克TV中完成扫码确认",
			Configured: snapshot.RefreshTokenValue() != "",
			Pending:    true,
			UpdatedAt:  latestQuarkTVUpdatedAt(snapshot),
		}, nil
	}

	tokenResp, err := client.exchangeToken(ctx, code, false)
	if err != nil {
		return QuarkTVLoginPollResult{
			Status:     "error",
			Message:    strings.TrimSpace(err.Error()),
			Configured: snapshot.RefreshTokenValue() != "",
			Pending:    true,
			UpdatedAt:  latestQuarkTVUpdatedAt(snapshot),
		}, nil
	}

	if _, err := upsertQuarkTVConfigForUser(userID, quarkTVRefreshTokenConfigKey, tokenResp.Data.RefreshToken); err != nil {
		return QuarkTVLoginPollResult{}, err
	}
	if _, err := upsertQuarkTVConfigForUser(userID, quarkTVDeviceIDConfigKey, client.deviceID); err != nil {
		return QuarkTVLoginPollResult{}, err
	}
	if err := deleteQuarkTVConfigByKeyForUser(userID, quarkTVQueryTokenConfigKey); err != nil {
		return QuarkTVLoginPollResult{}, err
	}

	cacheQuarkTVAccessToken(tokenResp.Data.RefreshToken, tokenResp.Data.AccessToken, tokenResp.Data.ExpiresIn)

	latestSnapshot, err := loadQuarkTVConfigSnapshotForUser(userID)
	if err != nil {
		return QuarkTVLoginPollResult{}, err
	}

	return QuarkTVLoginPollResult{
		Status:     "success",
		Message:    "夸克TV登录成功",
		Configured: true,
		Pending:    false,
		UpdatedAt:  latestQuarkTVUpdatedAt(latestSnapshot),
	}, nil
}

func getQuarkTVTranscodingLink(ctx context.Context, fid string) (quarkFileLink, error) {
	return getQuarkTVTranscodingLinkForUser(ctx, 0, fid)
}

func getQuarkTVTranscodingLinkForUser(ctx context.Context, userID uint, fid string) (quarkFileLink, error) {
	snapshot, err := loadQuarkTVConfigSnapshotForUser(userID)
	if err != nil {
		return quarkFileLink{}, err
	}
	refreshToken := snapshot.RefreshTokenValue()
	if refreshToken == "" {
		return quarkFileLink{}, errors.New("请先完成夸克TV登录")
	}

	client := newQuarkTVClient(snapshot)
	if err := client.ensureAccessToken(ctx); err != nil {
		return quarkFileLink{}, err
	}
	return client.getStreamingLink(ctx, fid)
}

func newQuarkTVClient(snapshot quarkTVConfigSnapshot) *quarkTVClient {
	client := &quarkTVClient{
		httpClient:   &http.Client{Timeout: quarkTVHTTPTimeout},
		refreshToken: snapshot.RefreshTokenValue(),
		deviceID:     snapshot.DeviceIDValue(),
	}
	if cachedAccessToken, ok := getCachedQuarkTVAccessToken(client.refreshToken); ok {
		client.accessToken = cachedAccessToken
	}
	return client
}

func (c *quarkTVClient) ensureAccessToken(ctx context.Context) error {
	if strings.TrimSpace(c.accessToken) != "" {
		return nil
	}
	if strings.TrimSpace(c.refreshToken) == "" {
		return errors.New("请先完成夸克TV登录")
	}
	_, err := c.exchangeToken(ctx, c.refreshToken, true)
	return err
}

func (c *quarkTVClient) getLoginQRCode(ctx context.Context) (string, string, error) {
	var resp quarkTVAuthorizeResponse
	if err := c.request(ctx, "/oauth/authorize", http.MethodGet, map[string]string{
		"auth_type": "code",
		"client_id": quarkTVClientID,
		"scope":     "netdisk",
		"qrcode":    "1",
		"qr_width":  "460",
		"qr_height": "460",
	}, nil, &resp, false); err != nil {
		return "", "", err
	}
	return strings.TrimSpace(resp.QrData), strings.TrimSpace(resp.QueryToken), nil
}

func (c *quarkTVClient) getLoginCode(ctx context.Context, queryToken string) (string, error) {
	var resp quarkTVCodeResponse
	if err := c.request(ctx, "/oauth/code", http.MethodGet, map[string]string{
		"client_id":   quarkTVClientID,
		"scope":       "netdisk",
		"query_token": strings.TrimSpace(queryToken),
	}, nil, &resp, false); err != nil {
		return "", err
	}
	return strings.TrimSpace(resp.Code), nil
}

func (c *quarkTVClient) getStreamingLink(ctx context.Context, fid string) (quarkFileLink, error) {
	var resp quarkTVStreamingResponse
	if err := c.request(ctx, "/file", http.MethodGet, map[string]string{
		"method":     "streaming",
		"group_by":   "source",
		"fid":        strings.TrimSpace(fid),
		"resolution": "low,normal,high,super,2k,4k",
		"support":    "dolby_vision",
	}, nil, &resp, true); err != nil {
		return quarkFileLink{}, fmt.Errorf("夸克TV转码链接获取失败: %w", err)
	}

	for _, item := range resp.Data.VideoInfo {
		if strings.TrimSpace(item.URL) == "" {
			continue
		}
		return quarkFileLink{
			URL:  strings.TrimSpace(item.URL),
			Size: item.Size,
		}, nil
	}

	return quarkFileLink{}, errors.New("夸克TV转码链接获取失败")
}

func (c *quarkTVClient) exchangeToken(ctx context.Context, codeOrRefreshToken string, refresh bool) (quarkTVTokenResponse, error) {
	_, _, reqID := generateQuarkTVRequestSign(http.MethodPost, "/token", strings.TrimSpace(c.deviceID))
	payload := map[string]string{
		"req_id":        reqID,
		"app_ver":       quarkTVAppVersion,
		"device_id":     strings.TrimSpace(c.deviceID),
		"device_brand":  quarkTVDeviceBrand,
		"platform":      quarkTVPlatform,
		"device_name":   quarkTVDeviceName,
		"device_model":  quarkTVDeviceModel,
		"build_device":  quarkTVBuildDevice,
		"build_product": quarkTVBuildProduct,
		"device_gpu":    quarkTVDeviceGPU,
		"activity_rect": quarkTVActivityRect,
		"channel":       quarkTVChannel,
	}
	if refresh {
		payload["refresh_token"] = strings.TrimSpace(codeOrRefreshToken)
	} else {
		payload["code"] = strings.TrimSpace(codeOrRefreshToken)
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return quarkTVTokenResponse{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, quarkTVCodeAPIBase+"/token", strings.NewReader(string(body)))
	if err != nil {
		return quarkTVTokenResponse{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/plain, */*")
	req.Header.Set("User-Agent", quarkTVUserAgent)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return quarkTVTokenResponse{}, err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= http.StatusBadRequest {
		msg := strings.TrimSpace(string(respBody))
		if msg == "" {
			msg = resp.Status
		}
		return quarkTVTokenResponse{}, errors.New(msg)
	}

	var tokenResp quarkTVTokenResponse
	if err := json.Unmarshal(respBody, &tokenResp); err != nil {
		return quarkTVTokenResponse{}, err
	}
	if tokenResp.Code != 200 {
		msg := strings.TrimSpace(tokenResp.Message)
		if msg == "" {
			msg = "夸克TV登录失败"
		}
		return quarkTVTokenResponse{}, errors.New(msg)
	}
	if tokenResp.Data.Errno != 0 || strings.TrimSpace(tokenResp.Data.ErrorInfo) != "" {
		msg := strings.TrimSpace(tokenResp.Data.ErrorInfo)
		if msg == "" {
			msg = "夸克TV登录失败"
		}
		return quarkTVTokenResponse{}, errors.New(msg)
	}
	if strings.TrimSpace(tokenResp.Data.AccessToken) == "" || strings.TrimSpace(tokenResp.Data.RefreshToken) == "" {
		return quarkTVTokenResponse{}, errors.New("夸克TV登录凭据为空")
	}

	c.accessToken = strings.TrimSpace(tokenResp.Data.AccessToken)
	c.refreshToken = strings.TrimSpace(tokenResp.Data.RefreshToken)
	cacheQuarkTVAccessToken(c.refreshToken, c.accessToken, tokenResp.Data.ExpiresIn)
	return tokenResp, nil
}

func (c *quarkTVClient) request(
	ctx context.Context,
	pathname string,
	method string,
	query map[string]string,
	payload any,
	target any,
	allowRefresh bool,
) error {
	body, envelope, err := c.doRequest(ctx, pathname, method, query, payload)
	if err == nil {
		if target != nil {
			if err := json.Unmarshal(body, target); err != nil {
				return err
			}
		}
		return nil
	}

	if allowRefresh && isQuarkTVAccessTokenInvalid(envelope) && strings.TrimSpace(c.refreshToken) != "" {
		if _, refreshErr := c.exchangeToken(ctx, c.refreshToken, true); refreshErr != nil {
			return refreshErr
		}
		body, _, retryErr := c.doRequest(ctx, pathname, method, query, payload)
		if retryErr != nil {
			return retryErr
		}
		if target != nil {
			if err := json.Unmarshal(body, target); err != nil {
				return err
			}
		}
		return nil
	}

	return err
}

func (c *quarkTVClient) doRequest(
	ctx context.Context,
	pathname string,
	method string,
	query map[string]string,
	payload any,
) ([]byte, quarkTVResponseEnvelope, error) {
	tm, token, reqID := generateQuarkTVRequestSign(method, pathname, strings.TrimSpace(c.deviceID))
	u, err := url.Parse(quarkTVAPIBaseURL + pathname)
	if err != nil {
		return nil, quarkTVResponseEnvelope{}, err
	}
	params := u.Query()
	params.Set("req_id", reqID)
	params.Set("access_token", strings.TrimSpace(c.accessToken))
	params.Set("app_ver", quarkTVAppVersion)
	params.Set("device_id", strings.TrimSpace(c.deviceID))
	params.Set("device_brand", quarkTVDeviceBrand)
	params.Set("platform", quarkTVPlatform)
	params.Set("device_name", quarkTVDeviceName)
	params.Set("device_model", quarkTVDeviceModel)
	params.Set("build_device", quarkTVBuildDevice)
	params.Set("build_product", quarkTVBuildProduct)
	params.Set("device_gpu", quarkTVDeviceGPU)
	params.Set("activity_rect", quarkTVActivityRect)
	params.Set("channel", quarkTVChannel)
	for key, value := range query {
		params.Set(key, value)
	}
	u.RawQuery = params.Encode()

	var bodyReader io.Reader
	if payload != nil {
		bodyBytes, err := json.Marshal(payload)
		if err != nil {
			return nil, quarkTVResponseEnvelope{}, err
		}
		bodyReader = strings.NewReader(string(bodyBytes))
	}

	req, err := http.NewRequestWithContext(ctx, method, u.String(), bodyReader)
	if err != nil {
		return nil, quarkTVResponseEnvelope{}, err
	}
	req.Header.Set("Accept", "application/json, text/plain, */*")
	req.Header.Set("User-Agent", quarkTVUserAgent)
	req.Header.Set("x-pan-tm", tm)
	req.Header.Set("x-pan-token", token)
	req.Header.Set("x-pan-client-id", quarkTVClientID)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, quarkTVResponseEnvelope{}, err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	var envelope quarkTVResponseEnvelope
	_ = json.Unmarshal(respBody, &envelope)

	if resp.StatusCode >= http.StatusBadRequest {
		msg := strings.TrimSpace(envelope.ErrorInfo)
		if msg == "" {
			msg = strings.TrimSpace(string(respBody))
		}
		if msg == "" {
			msg = resp.Status
		}
		return respBody, envelope, errors.New(msg)
	}
	if envelope.Errno != 0 || strings.TrimSpace(envelope.ErrorInfo) != "" {
		msg := strings.TrimSpace(envelope.ErrorInfo)
		if msg == "" {
			msg = "夸克TV接口请求失败"
		}
		return respBody, envelope, errors.New(msg)
	}
	return respBody, envelope, nil
}

func generateQuarkTVRequestSign(method string, pathname string, deviceID string) (string, string, string) {
	timestamp := fmt.Sprintf("%d", time.Now().UnixMilli())
	if strings.TrimSpace(deviceID) == "" {
		deviceID = generateQuarkTVDeviceID()
	}

	reqIDSum := md5.Sum([]byte(deviceID + timestamp))
	reqID := hex.EncodeToString(reqIDSum[:])

	tokenSum := sha256.Sum256([]byte(method + "&" + pathname + "&" + timestamp + "&" + quarkTVSignKey))
	token := hex.EncodeToString(tokenSum[:])

	return timestamp, token, reqID
}

func isQuarkTVAccessTokenInvalid(envelope quarkTVResponseEnvelope) bool {
	errInfoLower := strings.ToLower(strings.TrimSpace(envelope.ErrorInfo))
	return (envelope.Status == -1 && (envelope.Errno == 10001 || envelope.Errno == 11001)) ||
		strings.Contains(errInfoLower, "access token") ||
		strings.Contains(errInfoLower, "access_token") ||
		strings.Contains(errInfoLower, "token无效") ||
		strings.Contains(errInfoLower, "token 无效")
}

func classifyQuarkTVPollError(err error) string {
	if err == nil {
		return "pending"
	}
	message := strings.ToLower(strings.TrimSpace(err.Error()))
	switch {
	case containsAnySubstring(message,
		"pending", "wait", "scan", "confirm",
		"等待", "扫码", "确认", "授权中", "未确认"):
		return "pending"
	case containsAnySubstring(message,
		"expired", "expire", "invalid", "not exist",
		"已过期", "过期", "失效", "不存在"):
		return "expired"
	default:
		return "error"
	}
}

func containsAnySubstring(text string, keywords ...string) bool {
	for _, keyword := range keywords {
		if keyword != "" && strings.Contains(text, keyword) {
			return true
		}
	}
	return false
}

func buildQuarkTVLoginStatus(snapshot quarkTVConfigSnapshot) QuarkTVLoginStatus {
	return QuarkTVLoginStatus{
		Configured: snapshot.RefreshTokenValue() != "",
		Pending:    snapshot.QueryTokenValue() != "",
		UpdatedAt:  latestQuarkTVUpdatedAt(snapshot),
	}
}

func latestQuarkTVUpdatedAt(snapshot quarkTVConfigSnapshot) *time.Time {
	candidates := make([]time.Time, 0, 3)
	if snapshot.HasRefreshToken && !snapshot.RefreshToken.UpdatedAt.IsZero() {
		candidates = append(candidates, snapshot.RefreshToken.UpdatedAt)
	}
	if snapshot.HasQueryToken && !snapshot.QueryToken.UpdatedAt.IsZero() {
		candidates = append(candidates, snapshot.QueryToken.UpdatedAt)
	}
	if snapshot.HasDeviceID && !snapshot.DeviceID.UpdatedAt.IsZero() {
		candidates = append(candidates, snapshot.DeviceID.UpdatedAt)
	}
	if len(candidates) == 0 {
		return nil
	}
	latest := candidates[0]
	for _, candidate := range candidates[1:] {
		if candidate.After(latest) {
			latest = candidate
		}
	}
	return &latest
}

func loadQuarkTVConfigSnapshot() (quarkTVConfigSnapshot, error) {
	return loadQuarkTVConfigSnapshotForUser(0)
}

func loadQuarkTVConfigSnapshotForUser(userID uint) (quarkTVConfigSnapshot, error) {
	refreshToken, hasRefreshToken, err := getOptionalConfigByKeyForUser(userID, quarkTVRefreshTokenConfigKey)
	if err != nil {
		return quarkTVConfigSnapshot{}, err
	}
	deviceID, hasDeviceID, err := getOptionalConfigByKeyForUser(userID, quarkTVDeviceIDConfigKey)
	if err != nil {
		return quarkTVConfigSnapshot{}, err
	}
	queryToken, hasQueryToken, err := getOptionalConfigByKeyForUser(userID, quarkTVQueryTokenConfigKey)
	if err != nil {
		return quarkTVConfigSnapshot{}, err
	}

	return quarkTVConfigSnapshot{
		RefreshToken:    refreshToken,
		DeviceID:        deviceID,
		QueryToken:      queryToken,
		HasRefreshToken: hasRefreshToken,
		HasDeviceID:     hasDeviceID,
		HasQueryToken:   hasQueryToken,
	}, nil
}

func (s quarkTVConfigSnapshot) RefreshTokenValue() string {
	return strings.TrimSpace(s.RefreshToken.Value)
}

func (s quarkTVConfigSnapshot) DeviceIDValue() string {
	return strings.TrimSpace(s.DeviceID.Value)
}

func (s quarkTVConfigSnapshot) QueryTokenValue() string {
	return strings.TrimSpace(s.QueryToken.Value)
}

func getOptionalConfigByKey(key string) (model.Config, bool, error) {
	return getOptionalConfigByKeyForUser(0, key)
}

func getOptionalConfigByKeyForUser(userID uint, key string) (model.Config, bool, error) {
	if userID != 0 && isQuarkExclusiveMode(userID) {
		item, err := userConfigDao.GetByUserAndKey(userID, key)
		if err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return model.Config{}, false, nil
			}
			return model.Config{}, false, err
		}
		return model.Config{
			CommonModel: item.CommonModel,
			Name:        key,
			Key:         item.Key,
			Value:       item.Value,
			IsLock:      "1",
			Remark:      item.Remark,
		}, true, nil
	}
	cfg, err := configDao.GetByKey(key)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return model.Config{}, false, nil
		}
		return model.Config{}, false, err
	}
	return cfg, true, nil
}

func upsertQuarkTVConfig(key, value string) (model.Config, error) {
	return upsertQuarkTVConfigForUser(0, key, value)
}

func upsertQuarkTVConfigForUser(userID uint, key, value string) (model.Config, error) {
	name, remark := quarkTVConfigMeta(key)
	if userID != 0 && isQuarkExclusiveMode(userID) {
		if strings.TrimSpace(value) == "" {
			if err := userConfigDao.DeleteByUserAndKey(userID, key); err != nil {
				return model.Config{}, err
			}
			if key == quarkTVRefreshTokenConfigKey {
				clearCachedQuarkTVAccessToken()
			}
			return model.Config{}, nil
		}
		item, err := userConfigDao.Upsert(userID, key, strings.TrimSpace(value), remark)
		if err != nil {
			return model.Config{}, err
		}
		if key == quarkTVRefreshTokenConfigKey {
			clearCachedQuarkTVAccessToken()
		}
		return model.Config{
			CommonModel: item.CommonModel,
			Name:        name,
			Key:         item.Key,
			Value:       item.Value,
			IsLock:      "1",
			Remark:      item.Remark,
		}, nil
	}

	existing, exists, err := getOptionalConfigByKey(key)
	if err != nil {
		return model.Config{}, err
	}
	if strings.TrimSpace(value) == "" {
		if exists {
			if err := configDao.DeleteConfig(existing.ID); err != nil {
				return model.Config{}, err
			}
		}
		if key == quarkTVRefreshTokenConfigKey {
			clearCachedQuarkTVAccessToken()
		}
		return model.Config{}, nil
	}

	updateDTO := model.Config{
		CommonModel: existing.CommonModel,
		Name:        name,
		Key:         key,
		Value:       strings.TrimSpace(value),
		IsLock:      "1",
		Remark:      remark,
	}
	if exists {
		updateDTO.ID = existing.ID
	}
	if err := saveQuarkTVConfigModel(updateDTO); err != nil {
		return model.Config{}, err
	}
	saved, _, err := getOptionalConfigByKey(key)
	if err != nil {
		return model.Config{}, err
	}
	if key == quarkTVRefreshTokenConfigKey {
		clearCachedQuarkTVAccessToken()
	}
	return saved, nil
}

func deleteQuarkTVConfigByKey(key string) error {
	return deleteQuarkTVConfigByKeyForUser(0, key)
}

func deleteQuarkTVConfigByKeyForUser(userID uint, key string) error {
	if userID != 0 && isQuarkExclusiveMode(userID) {
		if err := userConfigDao.DeleteByUserAndKey(userID, key); err != nil {
			return err
		}
		if key == quarkTVRefreshTokenConfigKey {
			clearCachedQuarkTVAccessToken()
		}
		return nil
	}
	existing, exists, err := getOptionalConfigByKey(key)
	if err != nil {
		return err
	}
	if !exists {
		return nil
	}
	if err := configDao.DeleteConfig(existing.ID); err != nil {
		return err
	}
	if key == quarkTVRefreshTokenConfigKey {
		clearCachedQuarkTVAccessToken()
	}
	return nil
}

func quarkTVConfigMeta(key string) (string, string) {
	switch key {
	case quarkTVRefreshTokenConfigKey:
		return "夸克TV刷新令牌", "夸克TV扫码登录 refresh_token"
	case quarkTVDeviceIDConfigKey:
		return "夸克TV设备ID", "夸克TV扫码登录 device_id"
	case quarkTVQueryTokenConfigKey:
		return "夸克TV扫码令牌", "夸克TV扫码登录 query_token"
	default:
		return key, ""
	}
}

func generateQuarkTVDeviceID() string {
	sum := md5.Sum([]byte(fmt.Sprintf("%d", time.Now().UnixNano())))
	return hex.EncodeToString(sum[:])
}

func getCachedQuarkTVAccessToken(refreshToken string) (string, bool) {
	refreshToken = strings.TrimSpace(refreshToken)
	if refreshToken == "" {
		return "", false
	}
	now := time.Now()
	quarkTVAccessTokenCache.mu.RLock()
	defer quarkTVAccessTokenCache.mu.RUnlock()
	if quarkTVAccessTokenCache.refreshToken != refreshToken {
		return "", false
	}
	if strings.TrimSpace(quarkTVAccessTokenCache.accessToken) == "" {
		return "", false
	}
	if !quarkTVAccessTokenCache.expiresAt.After(now.Add(quarkTVTokenRefreshBuffer)) {
		return "", false
	}
	return quarkTVAccessTokenCache.accessToken, true
}

func cacheQuarkTVAccessToken(refreshToken, accessToken string, expiresIn int) {
	refreshToken = strings.TrimSpace(refreshToken)
	accessToken = strings.TrimSpace(accessToken)
	if refreshToken == "" || accessToken == "" {
		return
	}
	expiry := time.Now().Add(30 * time.Minute)
	if expiresIn > 0 {
		expiry = time.Now().Add(time.Duration(expiresIn) * time.Second)
	}
	quarkTVAccessTokenCache.mu.Lock()
	quarkTVAccessTokenCache.refreshToken = refreshToken
	quarkTVAccessTokenCache.accessToken = accessToken
	quarkTVAccessTokenCache.expiresAt = expiry
	quarkTVAccessTokenCache.mu.Unlock()
}

func clearCachedQuarkTVAccessToken() {
	quarkTVAccessTokenCache.mu.Lock()
	quarkTVAccessTokenCache.refreshToken = ""
	quarkTVAccessTokenCache.accessToken = ""
	quarkTVAccessTokenCache.expiresAt = time.Time{}
	quarkTVAccessTokenCache.mu.Unlock()
}

func saveQuarkTVConfigModel(cfg model.Config) error {
	return configDao.AddOrUpdateConfig(&dto.ConfigUpdateDTO{
		ID:     cfg.ID,
		Name:   cfg.Name,
		Key:    cfg.Key,
		Value:  cfg.Value,
		IsLock: cfg.IsLock,
		Remark: cfg.Remark,
	})
}
