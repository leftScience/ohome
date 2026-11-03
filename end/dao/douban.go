package dao

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"ohome/service/dto"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode"

	"github.com/PuerkitoBio/goquery"
)

type DoubanDao struct {
	BaseDao
}

const (
	doubanBaseURL  = "https://m.douban.com/rexxar/api/v2"
	hongguoBaseURL = "https://www.hongguostudio.com"
	lrtsBaseURL    = "https://www.lanrentingshu.com"
)

var hongguoVodIDRegex = regexp.MustCompile(`/voddetail/([^/.]+)\.html`)

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

func (d *DoubanDao) GetPlayletRanking(ctx context.Context, rankType string) (dto.DoubanRecentHotResp, error) {
	path := "/label/rank.html"
	switch strings.ToLower(strings.TrimSpace(rankType)) {
	case "month", "rankmonth", "月榜":
		path = "/label/rankmonth.html"
	case "week", "rankweek", "周榜":
		path = "/label/rankweek.html"
	}

	fullURL := strings.TrimRight(hongguoBaseURL, "/") + path
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fullURL, nil)
	if err != nil {
		return dto.DoubanRecentHotResp{}, err
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
	req.Header.Set("Referer", hongguoBaseURL+"/")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return dto.DoubanRecentHotResp{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return dto.DoubanRecentHotResp{}, fmt.Errorf("红果短剧排行榜请求失败: HTTP %d", resp.StatusCode)
	}

	items, err := ParseHongguoRankHTML(resp.Body)
	if err != nil {
		return dto.DoubanRecentHotResp{}, err
	}

	return dto.DoubanRecentHotResp{
		Items: items,
		Total: len(items),
		Categories: []dto.DoubanCategory{
			{Category: "rank", Type: "all", Title: "总榜", Selected: path == "/label/rank.html"},
			{Category: "rank", Type: "month", Title: "月榜", Selected: path == "/label/rankmonth.html"},
			{Category: "rank", Type: "week", Title: "周榜", Selected: path == "/label/rankweek.html"},
		},
	}, nil
}

func ParseHongguoRankHTML(r io.Reader) ([]any, error) {
	doc, err := goquery.NewDocumentFromReader(r)
	if err != nil {
		return nil, err
	}

	var items []any
	doc.Find(".hl-rank-list li.hl-list-item").Each(func(idx int, sel *goquery.Selection) {
		thumb := sel.Find(".hl-item-pic a.hl-item-thumb").First()
		titleLink := sel.Find(".hl-item-title a").First()

		title := strings.TrimSpace(titleLink.Text())
		if title == "" {
			title = strings.TrimSpace(titleLink.AttrOr("title", ""))
		}
		if title == "" {
			title = strings.TrimSpace(thumb.AttrOr("title", ""))
		}
		if title == "" {
			return
		}

		detailHref := strings.TrimSpace(titleLink.AttrOr("href", ""))
		if detailHref == "" {
			detailHref = strings.TrimSpace(thumb.AttrOr("href", ""))
		}
		vodID := extractHongguoVodID(detailHref)
		detailURL := resolveHongguoURL(detailHref)

		coverRaw := strings.TrimSpace(thumb.AttrOr("data-original", ""))
		if coverRaw == "" {
			coverRaw = strings.TrimSpace(thumb.AttrOr("src", ""))
		}
		coverURL := resolveHongguoURL(coverRaw)

		rankNum := idx + 1
		if rankText := strings.TrimSpace(sel.Find(".hl-item-num .hl-part-nums").First().Text()); rankText != "" {
			if parsedRank, err := strconv.Atoi(rankText); err == nil && parsedRank > 0 {
				rankNum = parsedRank
			}
		}

		remarks := strings.TrimSpace(sel.Find(".hl-item-remarks").First().Text())
		rawActors := strings.TrimSpace(sel.Find(".hl-item-sub").First().Text())
		actors := cleanHongguoActors(rawActors, title)

		var tags []string
		sel.Find(".hl-item-div3 .hl-item-datas").First().Find("span, a").Each(func(_ int, tagSel *goquery.Selection) {
			t := strings.TrimSpace(tagSel.Text())
			if t == "" || t == "未知" || t == "短剧" {
				return
			}
			tags = append(tags, t)
		})

		brief := strings.TrimSpace(sel.Find(".hl-item-div4 .hl-item-datas").First().Text())

		hitsText := strings.TrimSpace(sel.Find(".hl-item-div5 .hl-item-hits .hl-part-nums").First().Text())
		hits := 0
		if hitsText != "" {
			if v, err := strconv.Atoi(hitsText); err == nil && v > 0 {
				hits = v
			}
		}

		subtitleParts := make([]string, 0, 3)
		if len(tags) > 0 {
			subtitleParts = append(subtitleParts, strings.Join(tags, " / "))
		}
		if actors != "" {
			subtitleParts = append(subtitleParts, actors)
		}
		cardSubtitle := strings.Join(subtitleParts, " · ")
		if cardSubtitle == "" {
			cardSubtitle = brief
		}

		item := map[string]any{
			"id":            vodID,
			"rank":          rankNum,
			"title":         title,
			"card_subtitle": cardSubtitle,
			"subtitle":      cardSubtitle,
			"episodes_info": remarks,
			"remarks":       remarks,
			"actors":        actors,
			"brief":         brief,
			"hits":          hits,
			"hot":           formatHongguoHot(hits, hitsText),
			"cover_url":     coverURL,
			"cover":         coverURL,
			"url":           detailURL,
			"pic": map[string]any{
				"normal": coverURL,
				"large":  coverURL,
			},
		}
		items = append(items, item)
	})

	return items, nil
}

func resolveHongguoURL(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if strings.HasPrefix(raw, "http://") || strings.HasPrefix(raw, "https://") {
		return raw
	}
	if strings.HasPrefix(raw, "//") {
		return "https:" + raw
	}
	if !strings.HasPrefix(raw, "/") {
		raw = "/" + raw
	}
	return strings.TrimRight(hongguoBaseURL, "/") + raw
}

func extractHongguoVodID(href string) string {
	matches := hongguoVodIDRegex.FindStringSubmatch(href)
	if len(matches) >= 2 {
		return strings.TrimSpace(matches[1])
	}
	return ""
}

func cleanHongguoActors(raw, title string) string {
	cleaned := strings.TrimSpace(raw)
	cleaned = strings.Trim(cleaned, "/\\|·,， ")
	if cleaned == "" || cleaned == "未知" || cleaned == "内详" {
		return ""
	}
	if normalizeTextForCompare(cleaned) == normalizeTextForCompare(title) {
		return ""
	}
	parts := strings.FieldsFunc(cleaned, func(r rune) bool {
		return r == '/' || r == '＆' || r == '&' || r == '、' || r == ',' || r == '，'
	})
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" || p == "未知" || p == "内详" {
			continue
		}
		if normalizeTextForCompare(p) == normalizeTextForCompare(title) {
			continue
		}
		out = append(out, p)
	}
	return strings.Join(out, " / ")
}

func normalizeTextForCompare(s string) string {
	var b strings.Builder
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			b.WriteRune(unicode.ToLower(r))
		}
	}
	return b.String()
}

func formatHongguoHot(hits int, raw string) string {
	return formatHotCount(int64(hits), raw)
}

func formatHotCount(hits int64, raw string) string {
	if hits >= 100000000 {
		val := float64(hits) / 100000000.0
		return fmt.Sprintf("%.1f亿", val)
	}
	if hits >= 10000 {
		val := float64(hits) / 10000.0
		return fmt.Sprintf("%.1f万", val)
	}
	if hits > 0 {
		return strconv.FormatInt(hits, 10)
	}
	return strings.TrimSpace(raw)
}

type lrtsRankResponse struct {
	APIStatus int    `json:"apiStatus"`
	Status    int    `json:"status"`
	Msg       string `json:"msg"`
	Data      struct {
		List []lrtsRankItem `json:"list"`
	} `json:"data"`
}

type lrtsRankItem struct {
	ID             int64   `json:"id"`
	Name           string  `json:"name"`
	Cover          string  `json:"cover"`
	Author         string  `json:"author"`
	Announcer      string  `json:"announcer"`
	AnnouncerName  string  `json:"announcerName"`
	Desc           string  `json:"desc"`
	RecReason      string  `json:"recReason"`
	ShortRecReason string  `json:"shortRecReason"`
	TypeName       string  `json:"typeName"`
	CoreLabel      string  `json:"coreLabel"`
	Hot            int64   `json:"hot"`
	Score          float64 `json:"score"`
	State          int     `json:"state"`
	EntityType     int     `json:"entityType"`
}

func (d *DoubanDao) GetAudiobookRanking(ctx context.Context, category, rankType string) (dto.DoubanRecentHotResp, error) {
	rankID := "75"
	rangeType := "1"

	switch strings.ToLower(strings.TrimSpace(category)) {
	case "new", "新书榜":
		rankID = "738"
	case "search", "热搜榜":
		rankID = "77"
	case "praise", "好评榜":
		rankID = "76"
	case "collect", "收藏榜":
		rankID = "14479"
	case "finish", "完结榜":
		rankID = "739"
	case "free", "免费榜":
		rankID = "14481"
	}

	switch strings.ToLower(strings.TrimSpace(rankType)) {
	case "month", "月榜":
		rangeType = "2"
	case "all", "总榜":
		rangeType = "3"
	case "week", "周榜", "":
		rangeType = "1"
	}

	query := url.Values{}
	query.Set("rankId", rankID)
	query.Set("rangeType", rangeType)
	query.Set("pageSize", "100")

	fullURL := strings.TrimRight(lrtsBaseURL, "/") + "/api/ranking/resList?" + query.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fullURL, nil)
	if err != nil {
		return dto.DoubanRecentHotResp{}, err
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
	req.Header.Set("Referer", lrtsBaseURL+"/discover/ranking")
	req.Header.Set("Accept", "application/json, text/plain, */*")
	req.Header.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")

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
		return dto.DoubanRecentHotResp{}, fmt.Errorf("懒人听书排行榜请求失败: HTTP %d", resp.StatusCode)
	}

	items, err := ParseLrtsRankJSON(raw)
	if err != nil {
		return dto.DoubanRecentHotResp{}, err
	}

	return dto.DoubanRecentHotResp{
		Items: items,
		Total: len(items),
		Categories: []dto.DoubanCategory{
			{Category: "hot", Type: "week", Title: "周榜", Selected: rankID == "75" && rangeType == "1"},
			{Category: "hot", Type: "month", Title: "月榜", Selected: rankID == "75" && rangeType == "2"},
			{Category: "hot", Type: "all", Title: "总榜", Selected: rankID == "75" && rangeType == "3"},
		},
	}, nil
}

func ParseLrtsRankJSON(raw []byte) ([]any, error) {
	var parsed lrtsRankResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil, err
	}
	if parsed.Status != 0 && parsed.APIStatus != 0 {
		if strings.TrimSpace(parsed.Msg) != "" {
			return nil, errors.New(parsed.Msg)
		}
		return nil, errors.New("懒人听书排行榜返回异常状态")
	}

	items := make([]any, 0, len(parsed.Data.List))
	for idx, it := range parsed.Data.List {
		title := strings.TrimSpace(it.Name)
		if title == "" {
			continue
		}

		coverURL := strings.TrimSpace(it.Cover)
		if strings.HasPrefix(coverURL, "//") {
			coverURL = "https:" + coverURL
		}

		announcer := strings.TrimSpace(it.Announcer)
		if announcer == "" {
			announcer = strings.TrimSpace(it.AnnouncerName)
		}
		author := strings.TrimSpace(it.Author)
		typeName := strings.TrimSpace(it.TypeName)

		var subtitleParts []string
		if typeName != "" {
			subtitleParts = append(subtitleParts, typeName)
		}
		if author != "" {
			subtitleParts = append(subtitleParts, "作者: "+author)
		}
		if announcer != "" {
			subtitleParts = append(subtitleParts, "主播: "+announcer)
		}

		brief := strings.TrimSpace(it.RecReason)
		if brief == "" {
			brief = strings.TrimSpace(it.ShortRecReason)
		}
		if brief == "" {
			brief = strings.TrimSpace(it.Desc)
		}

		cardSubtitle := strings.Join(subtitleParts, " · ")
		if cardSubtitle == "" {
			cardSubtitle = brief
		}

		remarks := strings.TrimSpace(it.ShortRecReason)
		if remarks == "" {
			remarks = strings.TrimSpace(it.CoreLabel)
		}
		if remarks == "" {
			switch it.State {
			case 2:
				remarks = "完结"
			case 1:
				remarks = "连载"
			}
		}

		detailPath := "/book/"
		if it.EntityType == 2 {
			detailPath = "/album/"
		}
		detailURL := ""
		if it.ID > 0 {
			detailURL = strings.TrimRight(lrtsBaseURL, "/") + detailPath + strconv.FormatInt(it.ID, 10)
		}

		record := map[string]any{
			"id":            strconv.FormatInt(it.ID, 10),
			"rank":          idx + 1,
			"title":         title,
			"card_subtitle": cardSubtitle,
			"subtitle":      cardSubtitle,
			"episodes_info": remarks,
			"remarks":       remarks,
			"author":        author,
			"announcer":     announcer,
			"brief":         brief,
			"hits":          it.Hot,
			"hot":           formatHotCount(it.Hot, ""),
			"cover_url":     coverURL,
			"cover":         coverURL,
			"url":           detailURL,
			"pic": map[string]any{
				"normal": coverURL,
				"large":  coverURL,
			},
		}
		if it.Score > 0 {
			record["rating"] = map[string]any{
				"value": it.Score,
			}
		}
		items = append(items, record)
	}

	return items, nil
}
