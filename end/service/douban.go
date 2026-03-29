package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	neturl "net/url"
	"ohome/global"
	"ohome/service/dto"
	"strconv"
	"strings"
	"sync"
	"time"
)

type DoubanService struct {
	BaseService
}

const (
	doubanCacheKeyPrefix = "douban:recent_hot"
	doubanSyncLimit      = 100
	doubanCacheTTL       = 25 * time.Hour
)

var (
	doubanRecentHotCacheStore = make(map[string]doubanMemoryCacheEntry)
	doubanRecentHotCacheMu    sync.RWMutex
)

type doubanRecentHotCache struct {
	Records    []any                `json:"records"`
	Total      int                  `json:"total"`
	Category   string               `json:"category"`
	Type       string               `json:"type"`
	Categories []dto.DoubanCategory `json:"categories"`
	SyncedAt   int64                `json:"syncedAt"`
}

type doubanMemoryCacheEntry struct {
	Raw       string
	ExpiresAt time.Time
}

func (s *DoubanService) GetMovieCategories() map[string]map[string]dto.DoubanCategoryMappingItem {
	return map[string]map[string]dto.DoubanCategoryMappingItem{
		"热门电影": {
			"全部": {Category: "热门", Type: "全部"},
			"华语": {Category: "热门", Type: "华语"},
			"韩国": {Category: "热门", Type: "韩国"},
			"日本": {Category: "热门", Type: "日本"},
		},
		"最新电影": {
			"全部": {Category: "最新", Type: "全部"},
			"华语": {Category: "最新", Type: "华语"},
			"韩国": {Category: "最新", Type: "韩国"},
			"日本": {Category: "最新", Type: "日本"},
		},
		"豆瓣高分": {
			"全部": {Category: "豆瓣高分", Type: "全部"},
			"华语": {Category: "豆瓣高分", Type: "华语"},
			"韩国": {Category: "豆瓣高分", Type: "韩国"},
			"日本": {Category: "豆瓣高分", Type: "日本"},
		},
		"冷门佳片": {
			"全部": {Category: "冷门佳片", Type: "全部"},
			"华语": {Category: "冷门佳片", Type: "华语"},
			"韩国": {Category: "冷门佳片", Type: "韩国"},
			"日本": {Category: "冷门佳片", Type: "日本"},
		},
	}
}

func (s *DoubanService) GetTvCategories() map[string]map[string]dto.DoubanCategoryMappingItem {
	return map[string]map[string]dto.DoubanCategoryMappingItem{
		"最近热门剧集": {
			"综合":  {Category: "tv", Type: "tv"},
			"国产剧": {Category: "tv", Type: "tv_domestic"},
			"韩剧":  {Category: "tv", Type: "tv_korean"},
			"动画":  {Category: "tv", Type: "tv_animation"},
		},
		"最近热门综艺": {
			"综合": {Category: "show", Type: "show"},
			"国内": {Category: "show", Type: "show_domestic"},
			"国外": {Category: "show", Type: "show_foreign"},
		},
	}
}

func (s *DoubanService) GetAllCategories() map[string]any {
	return map[string]any{
		"movie": s.GetMovieCategories(),
		"tv":    s.GetTvCategories(),
	}
}

func (s *DoubanService) SyncAllCache(ctx context.Context) error {
	pairsMovie := s.flattenCategoryPairs(s.GetMovieCategories())
	pairsTv := s.flattenCategoryPairs(s.GetTvCategories())

	var firstErr error

	for _, p := range pairsMovie {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if _, err := s.syncRecentHotToCache(ctx, "movie", p.Category, p.Type); err != nil {
			if firstErr == nil {
				firstErr = err
			}
			global.Logger.Errorf("Douban Sync movie Error: %s", err.Error())
		}
	}

	for _, p := range pairsTv {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if _, err := s.syncRecentHotToCache(ctx, "tv", p.Category, p.Type); err != nil {
			if firstErr == nil {
				firstErr = err
			}
			global.Logger.Errorf("Douban Sync tv Error: %s", err.Error())
		}
	}

	return firstErr
}

func (s *DoubanService) GetMovieRankingWithProxy(ctx context.Context, category, typ string, page, limit int, proxyBase string) (map[string]any, error) {
	category = strings.TrimSpace(category)
	typ = strings.TrimSpace(typ)
	if category == "" {
		category = "热门"
	}
	if typ == "" {
		typ = "全部"
	}
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 10
	}
	if limit > 100 {
		return nil, errors.New("分页数量不能超过 100")
	}

	cache, err := s.getOrSyncRecentHotCache(ctx, "movie", category, typ)
	if err != nil {
		return nil, err
	}

	records := cache.Records
	total := cache.Total
	if total <= 0 {
		total = len(records)
	}
	categories := cache.Categories
	for i := range categories {
		categories[i].Selected = categories[i].Category == category && categories[i].Type == typ
	}

	start := (page - 1) * limit
	pageRecords := []any{}
	if start < len(records) {
		end := start + limit
		if end > len(records) {
			end = len(records)
		}
		pageRecords = records[start:end]
	}

	proxyBase = strings.TrimRight(strings.TrimSpace(proxyBase), "/")
	if proxyBase != "" {
		for _, r := range pageRecords {
			rewriteDoubanImageFields(r, proxyBase)
		}
	}

	data := map[string]any{
		"records":    pageRecords,
		"total":      total,
		"page":       page,
		"limit":      limit,
		"category":   category,
		"type":       typ,
		"categories": categories,
	}
	return data, nil
}

func (s *DoubanService) GetTvRankingWithProxy(ctx context.Context, category, typ string, page, limit int, proxyBase string) (map[string]any, error) {
	category = strings.TrimSpace(category)
	typ = strings.TrimSpace(typ)
	if category == "" {
		category = "tv"
	}
	if typ == "" {
		typ = "tv"
	}
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 10
	}
	if limit > 100 {
		return nil, errors.New("分页数量不能超过 100")
	}

	cache, err := s.getOrSyncRecentHotCache(ctx, "tv", category, typ)
	if err != nil {
		return nil, err
	}

	records := cache.Records
	total := cache.Total
	if total <= 0 {
		total = len(records)
	}
	categories := cache.Categories
	for i := range categories {
		categories[i].Selected = categories[i].Category == category && categories[i].Type == typ
	}

	start := (page - 1) * limit
	pageRecords := []any{}
	if start < len(records) {
		end := start + limit
		if end > len(records) {
			end = len(records)
		}
		pageRecords = records[start:end]
	}

	proxyBase = strings.TrimRight(strings.TrimSpace(proxyBase), "/")
	if proxyBase != "" {
		for _, r := range pageRecords {
			rewriteDoubanImageFields(r, proxyBase)
		}
	}

	data := map[string]any{
		"records":    pageRecords,
		"total":      total,
		"page":       page,
		"limit":      limit,
		"category":   category,
		"type":       typ,
		"categories": categories,
	}
	return data, nil
}

func (s *DoubanService) flattenCategoryPairs(source map[string]map[string]dto.DoubanCategoryMappingItem) []dto.DoubanCategoryMappingItem {
	unique := make(map[string]dto.DoubanCategoryMappingItem)
	for _, group := range source {
		for _, m := range group {
			key := fmt.Sprintf("%s|%s", m.Category, m.Type)
			unique[key] = m
		}
	}
	out := make([]dto.DoubanCategoryMappingItem, 0, len(unique))
	for _, v := range unique {
		out = append(out, v)
	}
	return out
}

func (s *DoubanService) getOrSyncRecentHotCache(ctx context.Context, subject, category, typ string) (doubanRecentHotCache, error) {
	cache, hit, err := s.getRecentHotCache(subject, category, typ)
	if err != nil {
		return doubanRecentHotCache{}, err
	}
	if hit {
		return cache, nil
	}
	return s.syncRecentHotToCache(ctx, subject, category, typ)
}

func (s *DoubanService) getRecentHotCache(subject, category, typ string) (doubanRecentHotCache, bool, error) {
	key := doubanRecentHotCacheKey(subject, category, typ)
	raw, ok := getDoubanMemoryCache(key)
	if !ok {
		return doubanRecentHotCache{}, false, nil
	}
	if strings.TrimSpace(raw) == "" {
		return doubanRecentHotCache{}, false, nil
	}

	var parsed doubanRecentHotCache
	if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
		return doubanRecentHotCache{}, false, nil
	}
	if len(parsed.Records) == 0 {
		return doubanRecentHotCache{}, false, nil
	}
	if parsed.Total <= 0 {
		parsed.Total = len(parsed.Records)
	}
	return parsed, true, nil
}

func (s *DoubanService) syncRecentHotToCache(ctx context.Context, subject, category, typ string) (doubanRecentHotCache, error) {
	defaultCategory := "热门"
	defaultType := "全部"
	if subject == "tv" {
		defaultCategory = "tv"
		defaultType = "tv"
	}

	query := neturl.Values{}
	query.Set("start", "0")
	query.Set("limit", strconv.Itoa(doubanSyncLimit))
	if strings.TrimSpace(category) != "" && category != defaultCategory {
		query.Set("category", category)
	}
	if strings.TrimSpace(typ) != "" && typ != defaultType {
		query.Set("type", typ)
	}

	resp, err := doubanDao.GetRecentHot(ctx, subject, query)
	if err != nil {
		return doubanRecentHotCache{}, err
	}

	items := resp.Items
	if len(items) == 0 {
		items = resp.Subjects
	}
	if len(items) == 0 {
		return doubanRecentHotCache{}, errors.New("豆瓣API返回空数据")
	}

	cache := doubanRecentHotCache{
		Records:    items,
		Total:      len(items),
		Category:   category,
		Type:       typ,
		Categories: resp.Categories,
		SyncedAt:   time.Now().Unix(),
	}

	b, err := json.Marshal(cache)
	if err != nil {
		return doubanRecentHotCache{}, err
	}

	key := doubanRecentHotCacheKey(subject, category, typ)
	setDoubanMemoryCache(key, string(b), doubanCacheTTL)

	return cache, nil
}

func doubanRecentHotCacheKey(subject, category, typ string) string {
	subject = strings.TrimSpace(subject)
	category = strings.TrimSpace(category)
	typ = strings.TrimSpace(typ)
	return fmt.Sprintf(
		"%s:%s:%s:%s",
		doubanCacheKeyPrefix,
		subject,
		neturl.QueryEscape(category),
		neturl.QueryEscape(typ),
	)
}

func getDoubanMemoryCache(key string) (string, bool) {
	now := time.Now()

	doubanRecentHotCacheMu.RLock()
	entry, ok := doubanRecentHotCacheStore[key]
	doubanRecentHotCacheMu.RUnlock()
	if !ok {
		return "", false
	}
	if !entry.ExpiresAt.IsZero() && !entry.ExpiresAt.After(now) {
		doubanRecentHotCacheMu.Lock()
		delete(doubanRecentHotCacheStore, key)
		doubanRecentHotCacheMu.Unlock()
		return "", false
	}
	return entry.Raw, true
}

func setDoubanMemoryCache(key, raw string, ttl time.Duration) {
	entry := doubanMemoryCacheEntry{Raw: raw}
	if ttl > 0 {
		entry.ExpiresAt = time.Now().Add(ttl)
	}

	doubanRecentHotCacheMu.Lock()
	doubanRecentHotCacheStore[key] = entry
	doubanRecentHotCacheMu.Unlock()
}

func (s *DoubanService) ProxyImage(ctx context.Context, rawURL string) (dto.DoubanImage, int, error) {
	target, err := sanitizeDoubanImageURL(rawURL)
	if err != nil {
		return dto.DoubanImage{}, 0, err
	}
	return doubanDao.FetchImage(ctx, target)
}

func sanitizeDoubanImageURL(raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", errors.New("链接不能为空")
	}
	if strings.HasPrefix(raw, "//") {
		raw = "https:" + raw
	}
	u, err := neturl.Parse(raw)
	if err != nil {
		return "", errors.New("链接格式不正确")
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return "", errors.New("只支持http/https协议")
	}
	if u.User != nil {
		return "", errors.New("链接不允许包含用户信息")
	}
	host := strings.ToLower(strings.TrimSpace(u.Hostname()))
	if host == "" {
		return "", errors.New("链接缺少主机名")
	}
	if !strings.HasSuffix(host, ".doubanio.com") || !strings.HasPrefix(host, "img") {
		return "", errors.New("只允许代理doubanio图片地址")
	}
	return u.String(), nil
}

func rewriteDoubanImageFields(record any, proxyBase string) {
	m, ok := record.(map[string]any)
	if !ok {
		return
	}

	if v, ok := m["cover_url"].(string); ok {
		m["cover_url"] = buildDoubanImageProxyURL(v, proxyBase)
	}
	if v, ok := m["cover"].(string); ok {
		m["cover"] = buildDoubanImageProxyURL(v, proxyBase)
	}

	if pic, ok := m["pic"].(map[string]any); ok {
		if v, ok := pic["normal"].(string); ok {
			pic["normal"] = buildDoubanImageProxyURL(v, proxyBase)
		}
		if v, ok := pic["large"].(string); ok {
			pic["large"] = buildDoubanImageProxyURL(v, proxyBase)
		}
	}

	if images, ok := m["images"].(map[string]any); ok {
		if v, ok := images["small"].(string); ok {
			images["small"] = buildDoubanImageProxyURL(v, proxyBase)
		}
		if v, ok := images["large"].(string); ok {
			images["large"] = buildDoubanImageProxyURL(v, proxyBase)
		}
	}

	if subject, ok := m["subject"].(map[string]any); ok {
		rewriteDoubanImageFields(subject, proxyBase)
	}
}

func buildDoubanImageProxyURL(raw string, proxyBase string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return raw
	}
	if strings.HasPrefix(raw, "//") {
		raw = "https:" + raw
	}
	u, err := neturl.Parse(raw)
	if err != nil {
		return raw
	}
	if u.Scheme == "" {
		u.Scheme = "https"
	}
	if u.Scheme == "http" {
		u.Scheme = "https"
	}
	host := strings.ToLower(u.Hostname())
	if !strings.HasSuffix(host, ".doubanio.com") {
		return u.String()
	}

	proxyBase = strings.TrimRight(strings.TrimSpace(proxyBase), "/")
	if proxyBase == "" {
		return u.String()
	}
	return proxyBase + "/api/v1/public/douban/image?url=" + neturl.QueryEscape(u.String())
}
