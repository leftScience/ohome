package quarksearch

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/PuerkitoBio/goquery"
)

var telegramImagePattern = regexp.MustCompile(`url\(['"]?([^'")]+)['"]?\)`)

const (
	tgMaxWorkers        = 24
	tgBatchTimeout      = 7 * time.Second
	tgChannelTimeout    = 4 * time.Second
	pluginSearchTimeout = 8 * time.Second
)

type telegramSearchJobResult struct {
	Results []SearchResult
	Err     error
}

func searchTelegram(ctx context.Context, client *http.Client, keyword string, channels []string) ([]SearchResult, error) {
	if len(channels) == 0 {
		return nil, nil
	}

	batchCtx, cancel := context.WithTimeout(ctx, tgBatchTimeout)
	defer cancel()

	jobChannels := make(chan string, len(channels))
	resultCh := make(chan telegramSearchJobResult, len(channels))
	totalJobs := 0
	for _, channel := range channels {
		channel = strings.TrimSpace(channel)
		if channel == "" {
			continue
		}
		jobChannels <- channel
		totalJobs++
	}
	close(jobChannels)

	if totalJobs == 0 {
		return nil, nil
	}

	workerCount := totalJobs
	if workerCount > tgMaxWorkers {
		workerCount = tgMaxWorkers
	}

	var wg sync.WaitGroup
	for i := 0; i < workerCount; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for channel := range jobChannels {
				channelCtx, channelCancel := context.WithTimeout(batchCtx, tgChannelTimeout)
				items, err := searchTelegramChannel(channelCtx, client, keyword, channel)
				channelCancel()

				select {
				case resultCh <- telegramSearchJobResult{Results: items, Err: err}:
				case <-batchCtx.Done():
					return
				}
			}
		}()
	}

	go func() {
		wg.Wait()
		close(resultCh)
	}()

	results := make([]SearchResult, 0, totalJobs*2)
	var firstErr error
	for {
		select {
		case result, ok := <-resultCh:
			if !ok {
				if len(results) == 0 && firstErr != nil {
					return nil, firstErr
				}
				return results, nil
			}
			if result.Err != nil {
				if firstErr == nil {
					firstErr = result.Err
				}
				continue
			}
			results = append(results, result.Results...)
		case <-batchCtx.Done():
			if len(results) == 0 && firstErr != nil {
				return nil, firstErr
			}
			return results, nil
		}
	}
}

func searchTelegramChannel(ctx context.Context, client *http.Client, keyword string, channel string) ([]SearchResult, error) {
	searchURL := "https://t.me/s/" + channel + "?q=" + url.QueryEscape(strings.TrimSpace(keyword))
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, searchURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", defaultUserAgent)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
	req.Header.Set("Referer", "https://t.me/s/"+channel)

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Telegram 频道 %s 请求失败：%w", channel, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Telegram 频道 %s 返回状态码 %d", channel, resp.StatusCode)
	}

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Telegram 频道 %s 解析失败：%w", channel, err)
	}

	results := make([]SearchResult, 0, 8)
	seen := make(map[string]struct{}, 8)

	doc.Find(".tgme_widget_message_wrap").Each(func(_ int, selection *goquery.Selection) {
		message := selection.Find(".tgme_widget_message")
		if message.Length() == 0 {
			return
		}

		dataPost, exists := message.Attr("data-post")
		if !exists {
			return
		}
		parts := strings.Split(dataPost, "/")
		if len(parts) != 2 {
			return
		}
		messageID := parts[1]
		uniqueID := channel + "_" + messageID
		if _, exists := seen[uniqueID]; exists {
			return
		}

		textSelection := message.Find(".tgme_widget_message_text")
		if textSelection.Length() == 0 {
			textSelection = message.Find(".tgme_widget_message_caption")
		}
		text := cleanText(textSelection.Text())

		hrefs := make([]string, 0, 4)
		textSelection.Find("a").Each(func(_ int, anchor *goquery.Selection) {
			if href, ok := anchor.Attr("href"); ok {
				hrefs = append(hrefs, href)
			}
		})
		message.Find("a").Each(func(_ int, anchor *goquery.Selection) {
			if href, ok := anchor.Attr("href"); ok {
				hrefs = append(hrefs, href)
			}
		})

		links := extractQuarkLinks(text, hrefs)
		if len(links) == 0 {
			return
		}

		datetime := timeFromSelection(message)
		images := extractTelegramImages(message)

		results = append(results, SearchResult{
			MessageID: messageID,
			UniqueID:  uniqueID,
			Channel:   channel,
			Datetime:  datetime,
			Title:     extractTitle(text),
			Content:   text,
			Links:     links,
			Images:    images,
		})
		seen[uniqueID] = struct{}{}
	})

	return filterResultsByKeyword(results, keyword), nil
}

func timeFromSelection(message *goquery.Selection) time.Time {
	timeText, exists := message.Find(".tgme_widget_message_date time").Attr("datetime")
	if !exists {
		return time.Time{}
	}
	return parseTime(timeText)
}

func extractTelegramImages(message *goquery.Selection) []string {
	images := make([]string, 0, 4)
	seen := make(map[string]struct{}, 4)

	message.Find(".tgme_widget_message_photo_wrap").Each(func(_ int, selection *goquery.Selection) {
		style, exists := selection.Attr("style")
		if !exists {
			return
		}
		match := telegramImagePattern.FindStringSubmatch(style)
		if len(match) < 2 {
			return
		}
		image := strings.TrimSpace(match[1])
		if image == "" {
			return
		}
		if _, exists := seen[image]; exists {
			return
		}
		seen[image] = struct{}{}
		images = append(images, image)
	})

	return images
}
