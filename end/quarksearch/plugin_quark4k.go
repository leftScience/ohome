package quarksearch

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

type Quark4KPlugin struct{}

func (Quark4KPlugin) Name() string { return "quark4k" }

func (Quark4KPlugin) Search(ctx context.Context, client *http.Client, keyword string, ext map[string]any) ([]SearchResult, error) {
	results := make([]SearchResult, 0, 16)
	for page := 0; page < 2; page++ {
		pageResults, hasMore, err := fetchQuark4KPage(ctx, client, keyword, page*50)
		if err != nil {
			if page == 0 {
				return nil, err
			}
			break
		}
		results = append(results, pageResults...)
		if !hasMore {
			break
		}
	}
	return filterResultsByKeyword(results, keyword), nil
}

func fetchQuark4KPage(ctx context.Context, client *http.Client, keyword string, offset int) ([]SearchResult, bool, error) {
	apiURL := fmt.Sprintf("https://quark4k.com/api/discussions?include=user%%2ClastPostedUser%%2CmostRelevantPost%%2CmostRelevantPost.user%%2Ctags%%2Ctags.parent%%2CfirstPost&filter[q]=%s&sort&page[offset]=%d&page[limit]=50",
		url.QueryEscape(strings.TrimSpace(keyword)),
		offset,
	)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, apiURL, nil)
	if err != nil {
		return nil, false, err
	}
	req.Header.Set("User-Agent", defaultUserAgent)
	req.Header.Set("Accept", "application/json, text/plain, */*")
	req.Header.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
	req.Header.Set("Referer", "https://quark4k.com/")

	resp, err := client.Do(req)
	if err != nil {
		return nil, false, fmt.Errorf("quark4k 请求失败：%w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, false, fmt.Errorf("quark4k 返回状态码 %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, false, err
	}

	var apiResp quark4kResponse
	if err := json.Unmarshal(body, &apiResp); err != nil {
		return nil, false, fmt.Errorf("quark4k 响应解析失败：%w", err)
	}

	postMap := make(map[string]quark4kPost, len(apiResp.Included))
	for _, item := range apiResp.Included {
		if item.Type != "posts" {
			continue
		}
		var post quark4kPost
		if err := json.Unmarshal(item.Attributes, &post.Attributes); err != nil {
			continue
		}
		post.ID = item.ID
		postMap[item.ID] = post
	}

	results := make([]SearchResult, 0, len(apiResp.Data))
	for _, discussion := range apiResp.Data {
		post, exists := postMap[discussion.Relationships.MostRelevantPost.Data.ID]
		if !exists {
			continue
		}

		content := cleanHTMLText(post.Attributes.ContentHTML)
		links := extractQuarkLinks(content, nil)
		if len(links) == 0 {
			continue
		}

		results = append(results, SearchResult{
			UniqueID: fmt.Sprintf("quark4k-%s", discussion.ID),
			Title:    cleanText(discussion.Attributes.Title),
			Content:  content,
			Datetime: parseTime(discussion.Attributes.CreatedAt),
			Links:    links,
		})
	}

	return results, strings.TrimSpace(apiResp.Links.Next) != "", nil
}

type quark4kResponse struct {
	Links    quark4kLinks          `json:"links"`
	Data     []quark4kDiscussion   `json:"data"`
	Included []quark4kIncludedItem `json:"included"`
}

type quark4kLinks struct {
	Next string `json:"next"`
}

type quark4kDiscussion struct {
	ID            string                    `json:"id"`
	Attributes    quark4kDiscussionAttrs    `json:"attributes"`
	Relationships quark4kDiscussionRelation `json:"relationships"`
}

type quark4kDiscussionAttrs struct {
	Title     string `json:"title"`
	CreatedAt string `json:"createdAt"`
}

type quark4kDiscussionRelation struct {
	MostRelevantPost quark4kPostRef `json:"mostRelevantPost"`
}

type quark4kPostRef struct {
	Data quark4kPostData `json:"data"`
}

type quark4kPostData struct {
	ID string `json:"id"`
}

type quark4kIncludedItem struct {
	Type       string          `json:"type"`
	ID         string          `json:"id"`
	Attributes json.RawMessage `json:"attributes"`
}

type quark4kPost struct {
	ID         string
	Attributes quark4kPostAttrs
}

type quark4kPostAttrs struct {
	ContentHTML string `json:"contentHtml"`
}
