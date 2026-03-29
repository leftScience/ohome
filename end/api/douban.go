package api

import (
	"fmt"
	"net/http"
	"ohome/utils"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type DoubanApi struct {
	BaseApi
}

func NewDoubanApi() DoubanApi {
	return DoubanApi{
		BaseApi: NewBaseApi(),
	}
}

func (a *DoubanApi) Health(c *gin.Context) {
	utils.OkWithData(gin.H{
		"status":    "ok",
		"message":   "豆瓣API服务运行正常",
		"timestamp": time.Now().Format(time.RFC3339),
	}, c)
}

func (a *DoubanApi) Doc(c *gin.Context) {
	base := "/api/v1/public"
	utils.OkWithData(gin.H{
		"name":        "douban-api",
		"version":     "1.0.0",
		"description": "豆瓣API服务 - 基于豆瓣移动端API获取影视热门榜单数据（已迁移到 ohome server）",
		"basePath":    base,
		"endpoints": gin.H{
			"douban": gin.H{
				"health":     base + "/douban/health",
				"categories": base + "/douban/categories",
			},
			"movie": gin.H{
				"recent_hot": base + "/douban/movie/recent_hot",
				"hot":        base + "/douban/movie/hot/:type?",
				"latest":     base + "/douban/movie/latest/:type?",
				"top":        base + "/douban/movie/top/:type?",
				"underrated": base + "/douban/movie/underrated/:type?",
				"categories": base + "/douban/movie/categories",
				"example":    base + "/douban/movie/hot/全部?page=1&limit=10",
			},
			"tv": gin.H{
				"recent_hot": base + "/douban/tv/recent_hot",
				"drama":      base + "/douban/tv/drama/:type?",
				"variety":    base + "/douban/tv/variety/:type?",
				"categories": base + "/douban/tv/categories",
				"example":    base + "/douban/tv/drama/韩剧?page=1&limit=10",
			},
			"legacy": gin.H{
				"recent_hot": base + "/douban/recent_hot?type=movie&category=热门&subtype=全部&page=1&limit=10",
			},
		},
	}, c)
}

func (a *DoubanApi) GetMovieCategories(c *gin.Context) {
	utils.OkWithData(doubanService.GetMovieCategories(), c)
}

func (a *DoubanApi) GetTvCategories(c *gin.Context) {
	utils.OkWithData(doubanService.GetTvCategories(), c)
}

func (a *DoubanApi) GetAllCategories(c *gin.Context) {
	utils.OkWithData(doubanService.GetAllCategories(), c)
}

func (a *DoubanApi) GetMovieRecentHot(c *gin.Context) {
	category := c.DefaultQuery("category", "热门")
	typ := c.DefaultQuery("type", "全部")
	page, limit := parsePageLimit(c)

	data, err := doubanService.GetMovieRankingWithProxy(
		c.Request.Context(),
		category,
		typ,
		page,
		limit,
		requestBaseURL(c),
	)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取电影榜单成功: %s - %s", category, typ), c)
}

func (a *DoubanApi) GetMovieHot(c *gin.Context) {
	typ := strings.TrimSpace(c.Param("type"))
	if typ == "" {
		typ = "全部"
	}
	page, limit := parsePageLimit(c)

	data, err := doubanService.GetMovieRankingWithProxy(
		c.Request.Context(),
		"热门",
		typ,
		page,
		limit,
		requestBaseURL(c),
	)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取热门电影榜单成功: %s", typ), c)
}

func (a *DoubanApi) GetMovieLatest(c *gin.Context) {
	typ := strings.TrimSpace(c.Param("type"))
	if typ == "" {
		typ = "全部"
	}
	page, limit := parsePageLimit(c)

	data, err := doubanService.GetMovieRankingWithProxy(
		c.Request.Context(),
		"最新",
		typ,
		page,
		limit,
		requestBaseURL(c),
	)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取最新电影榜单成功: %s", typ), c)
}

func (a *DoubanApi) GetMovieTop(c *gin.Context) {
	typ := strings.TrimSpace(c.Param("type"))
	if typ == "" {
		typ = "全部"
	}
	page, limit := parsePageLimit(c)

	data, err := doubanService.GetMovieRankingWithProxy(
		c.Request.Context(),
		"豆瓣高分",
		typ,
		page,
		limit,
		requestBaseURL(c),
	)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取豆瓣高分电影榜单成功: %s", typ), c)
}

func (a *DoubanApi) GetMovieUnderrated(c *gin.Context) {
	typ := strings.TrimSpace(c.Param("type"))
	if typ == "" {
		typ = "全部"
	}
	page, limit := parsePageLimit(c)

	data, err := doubanService.GetMovieRankingWithProxy(
		c.Request.Context(),
		"冷门佳片",
		typ,
		page,
		limit,
		requestBaseURL(c),
	)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取冷门佳片榜单成功: %s", typ), c)
}

func (a *DoubanApi) GetTvRecentHot(c *gin.Context) {
	category := c.DefaultQuery("category", "tv")
	typ := c.DefaultQuery("type", "tv")
	page, limit := parsePageLimit(c)

	data, err := doubanService.GetTvRankingWithProxy(
		c.Request.Context(),
		category,
		typ,
		page,
		limit,
		requestBaseURL(c),
	)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取电视剧榜单成功: %s - %s", category, typ), c)
}

func (a *DoubanApi) GetTvDrama(c *gin.Context) {
	label := strings.TrimSpace(c.Param("type"))
	if label == "" {
		label = "综合"
	}
	category, typ := mapTvDrama(label)
	page, limit := parsePageLimit(c)

	data, err := doubanService.GetTvRankingWithProxy(
		c.Request.Context(),
		category,
		typ,
		page,
		limit,
		requestBaseURL(c),
	)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取最近热门剧集榜单成功: %s", label), c)
}

func (a *DoubanApi) GetTvVariety(c *gin.Context) {
	label := strings.TrimSpace(c.Param("type"))
	if label == "" {
		label = "综合"
	}
	category, typ := mapTvVariety(label)
	page, limit := parsePageLimit(c)

	data, err := doubanService.GetTvRankingWithProxy(
		c.Request.Context(),
		category,
		typ,
		page,
		limit,
		requestBaseURL(c),
	)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取最近热门综艺榜单成功: %s", label), c)
}

func (a *DoubanApi) GetRecentHotLegacy(c *gin.Context) {
	kind := strings.TrimSpace(c.DefaultQuery("type", "movie"))
	category := c.DefaultQuery("category", "热门")
	subtype := c.DefaultQuery("subtype", "全部")
	page, limit := parsePageLimit(c)

	var (
		data map[string]any
		err  error
	)

	switch kind {
	case "movie":
		data, err = doubanService.GetMovieRankingWithProxy(
			c.Request.Context(),
			category,
			subtype,
			page,
			limit,
			requestBaseURL(c),
		)
	case "tv":
		data, err = doubanService.GetTvRankingWithProxy(
			c.Request.Context(),
			category,
			subtype,
			page,
			limit,
			requestBaseURL(c),
		)
	default:
		utils.FailWithMessage("类型参数只支持 movie 或 tv", c)
		return
	}

	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	kindName := "电视剧"
	if kind == "movie" {
		kindName = "电影"
	}
	utils.OkWithDetailed(data, fmt.Sprintf("获取%s榜单成功", kindName), c)
}

func (a *DoubanApi) GetImage(c *gin.Context) {
	rawURL := strings.TrimSpace(c.Query("url"))
	img, status, err := doubanService.ProxyImage(c.Request.Context(), rawURL)
	if err != nil {
		c.String(http.StatusBadRequest, err.Error())
		return
	}
	defer img.Body.Close()

	if status != http.StatusOK {
		c.Status(status)
		return
	}

	cacheControl := strings.TrimSpace(img.CacheControl)
	if cacheControl == "" {
		cacheControl = "public, max-age=604800"
	}

	headers := map[string]string{
		"Cache-Control": cacheControl,
	}
	if img.ETag != "" {
		headers["ETag"] = img.ETag
	}
	if img.LastModified != "" {
		headers["Last-Modified"] = img.LastModified
	}

	c.DataFromReader(http.StatusOK, img.ContentLength, img.ContentType, img.Body, headers)
}

func parsePageLimit(c *gin.Context) (int, int) {
	page := 0
	limit := 0

	if s := strings.TrimSpace(c.Query("page")); s != "" {
		if v, err := strconv.Atoi(s); err == nil {
			page = v
		}
	}
	if s := strings.TrimSpace(c.Query("limit")); s != "" {
		if v, err := strconv.Atoi(s); err == nil {
			limit = v
		}
	}

	// 兼容旧参数 start：当没传 page 时，按 offset 推导 page（start=0 -> page=1）
	if page == 0 {
		if s := strings.TrimSpace(c.Query("start")); s != "" {
			if v, err := strconv.Atoi(s); err == nil && v >= 0 {
				if limit <= 0 {
					limit = 10
				}
				page = v/limit + 1
			}
		}
	}

	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 10
	}
	return page, limit
}

func requestBaseURL(c *gin.Context) string {
	proto := strings.TrimSpace(c.GetHeader("X-Forwarded-Proto"))
	if proto == "" {
		if c.Request.TLS != nil {
			proto = "https"
		} else {
			proto = "http"
		}
	}

	host := strings.TrimSpace(c.GetHeader("X-Forwarded-Host"))
	if host == "" {
		host = strings.TrimSpace(c.Request.Host)
	}
	if host == "" {
		return ""
	}

	return proto + "://" + host
}

func mapTvDrama(label string) (string, string) {
	switch label {
	case "综合":
		return "tv", "tv"
	case "国产剧":
		return "tv", "tv_domestic"
	case "韩剧":
		return "tv", "tv_korean"
	case "动画":
		return "tv", "tv_animation"
	default:
		return "tv", "tv"
	}
}

func mapTvVariety(label string) (string, string) {
	switch label {
	case "综合":
		return "show", "show"
	case "国内":
		return "show", "show_domestic"
	case "国外":
		return "show", "show_foreign"
	default:
		return "show", "show"
	}
}
