package quarksearch

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"sync"
)

const defaultUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

type Plugin interface {
	Name() string
	Search(ctx context.Context, client *http.Client, keyword string, ext map[string]any) ([]SearchResult, error)
}

type Engine struct {
	plugins          map[string]Plugin
	cachedClients    sync.Map
	responseGroup    flightGroup
	tgGroup          flightGroup
	pluginGroup      flightGroup
	telegramSearchFn func(ctx context.Context, client *http.Client, settings Settings, keyword string, channels []string) ([]SearchResult, error)
}

func NewEngine() *Engine {
	return &Engine{
		plugins: SupportedPlugins(),
	}
}

func (e *Engine) Search(ctx context.Context, settings Settings, req Request) (SearchResponse, error) {
	keyword := strings.TrimSpace(req.Keyword)
	if keyword == "" {
		return SearchResponse{}, errors.New("关键词不能为空")
	}

	sourceType := strings.ToLower(strings.TrimSpace(req.SourceType))
	if sourceType == "" {
		sourceType = "all"
	}
	resultType := strings.ToLower(strings.TrimSpace(req.ResultType))
	if resultType == "" || resultType == "merge" {
		resultType = "merged_by_type"
	}

	channels := resolveChannels(req.Channels, settings.Channels)
	pluginNames := resolvePluginNames(req.Plugins, settings.EnabledPlugins, e.plugins)
	tgEnabled := (sourceType == "all" || sourceType == "tg") && len(channels) > 0
	pluginEnabled := (sourceType == "all" || sourceType == "plugin") && len(pluginNames) > 0
	concurrency := req.Concurrency
	if concurrency <= 0 {
		concurrency = len(pluginNames)
	}
	if concurrency <= 0 {
		concurrency = 1
	}

	requestKey := e.requestKey(settings, req, channels, pluginNames, sourceType, resultType)
	value, err, _ := e.responseGroup.Do(requestKey, func() (any, error) {
		client := e.getClient(settings)
		allResults := make([]SearchResult, 0, 32)
		var (
			wg            sync.WaitGroup
			tgResults     []SearchResult
			pluginResults []SearchResult
			tgErr         error
			pluginErr     error
		)

		if sourceType == "all" || sourceType == "tg" {
			wg.Add(1)
			go func() {
				defer wg.Done()
				tgResults, tgErr = e.runTelegramSearch(ctx, client, settings, keyword, channels)
			}()
		}

		if sourceType == "all" || sourceType == "plugin" {
			wg.Add(1)
			go func() {
				defer wg.Done()
				pluginResults, pluginErr = e.searchPlugins(ctx, client, settings, keyword, pluginNames, copyExt(req.Ext), concurrency)
			}()
		}
		wg.Wait()

		allResults = append(allResults, tgResults...)
		allResults = append(allResults, pluginResults...)

		if len(allResults) == 0 {
			if err := selectSearchError(tgEnabled, tgErr, pluginEnabled, pluginErr); err != nil {
				return SearchResponse{}, err
			}
		}

		allResults = applyFilterConfig(allResults, req.Filter)
		sortResults(allResults, keyword)

		response := SearchResponse{
			Results:      allResults,
			MergedByType: mergeResultsByType(allResults),
		}
		if links, exists := response.MergedByType["quark"]; exists {
			response.Total = len(links)
		}
		if resultType == "results" {
			response.Total = len(response.Results)
		}
		if resultType == "all" && response.Total == 0 {
			response.Total = len(response.Results)
		}

		return filterResponseByType(response, resultType), nil
	})
	if err != nil {
		return SearchResponse{}, err
	}
	response, ok := value.(SearchResponse)
	if !ok {
		return SearchResponse{}, errors.New("搜索响应格式无效")
	}
	return response, nil
}

func (e *Engine) runTelegramSearch(ctx context.Context, client *http.Client, settings Settings, keyword string, channels []string) ([]SearchResult, error) {
	if e.telegramSearchFn != nil {
		return e.telegramSearchFn(ctx, client, settings, keyword, channels)
	}
	return e.searchTelegram(ctx, client, settings, keyword, channels)
}

func (e *Engine) searchTelegram(ctx context.Context, client *http.Client, settings Settings, keyword string, channels []string) ([]SearchResult, error) {
	stageKey := stageKey("tg", settings, keyword, channels, nil, nil)
	value, err, _ := e.tgGroup.Do(stageKey, func() (any, error) {
		return searchTelegram(ctx, client, keyword, channels)
	})
	if err != nil {
		return nil, err
	}
	results, ok := value.([]SearchResult)
	if !ok {
		return nil, errors.New("Telegram 搜索响应格式无效")
	}
	return results, nil
}

func (e *Engine) searchPlugins(ctx context.Context, client *http.Client, settings Settings, keyword string, names []string, ext map[string]any, concurrency int) ([]SearchResult, error) {
	if len(names) == 0 {
		return nil, nil
	}
	if concurrency <= 0 {
		concurrency = len(names)
	}
	if concurrency <= 0 {
		concurrency = 1
	}

	stageKey := stageKey("plugin", settings, keyword, nil, names, ext)
	value, err, _ := e.pluginGroup.Do(stageKey, func() (any, error) {
		sem := make(chan struct{}, concurrency)
		var (
			wg      sync.WaitGroup
			mu      sync.Mutex
			results []SearchResult
			errs    []error
		)

		for _, name := range names {
			plugin, exists := e.plugins[name]
			if !exists {
				continue
			}
			wg.Add(1)
			go func(plugin Plugin) {
				defer wg.Done()
				select {
				case sem <- struct{}{}:
				case <-ctx.Done():
					return
				}
				defer func() { <-sem }()

				pluginCtx, cancel := context.WithTimeout(ctx, pluginSearchTimeout)
				defer cancel()

				items, err := plugin.Search(pluginCtx, client, keyword, copyExt(ext))
				mu.Lock()
				defer mu.Unlock()
				if err != nil {
					errs = append(errs, err)
					return
				}
				results = append(results, items...)
			}(plugin)
		}

		wg.Wait()
		if len(results) == 0 && len(errs) > 0 {
			return []SearchResult(nil), errs[0]
		}
		return results, nil
	})
	if err != nil {
		return nil, err
	}
	results, ok := value.([]SearchResult)
	if !ok {
		return nil, errors.New("插件搜索响应格式无效")
	}
	return results, nil
}

func (e *Engine) getClient(settings Settings) *http.Client {
	key := strings.TrimSpace(settings.HTTPProxy) + "|" + strings.TrimSpace(settings.HTTPSProxy)
	if value, ok := e.cachedClients.Load(key); ok {
		if client, ok := value.(*http.Client); ok && client != nil {
			return client
		}
	}

	client := newHTTPClient(settings)
	actual, _ := e.cachedClients.LoadOrStore(key, client)
	if shared, ok := actual.(*http.Client); ok && shared != nil {
		return shared
	}
	return client
}

func selectSearchError(tgEnabled bool, tgErr error, pluginEnabled bool, pluginErr error) error {
	if tgEnabled && tgErr == nil {
		return nil
	}
	if pluginEnabled && pluginErr == nil {
		return nil
	}
	if tgEnabled && tgErr != nil {
		return tgErr
	}
	if pluginEnabled && pluginErr != nil {
		return pluginErr
	}
	return nil
}

func (e *Engine) requestKey(settings Settings, req Request, channels, plugins []string, sourceType, resultType string) string {
	payload := struct {
		Keyword     string         `json:"keyword"`
		Channels    []string       `json:"channels"`
		Plugins     []string       `json:"plugins"`
		Concurrency int            `json:"concurrency"`
		SourceType  string         `json:"source_type"`
		ResultType  string         `json:"result_type"`
		HTTPProxy   string         `json:"http_proxy"`
		HTTPSProxy  string         `json:"https_proxy"`
		Ext         map[string]any `json:"ext"`
		Filter      *FilterConfig  `json:"filter,omitempty"`
	}{
		Keyword:     strings.TrimSpace(req.Keyword),
		Channels:    channels,
		Plugins:     plugins,
		Concurrency: req.Concurrency,
		SourceType:  sourceType,
		ResultType:  resultType,
		HTTPProxy:   strings.TrimSpace(settings.HTTPProxy),
		HTTPSProxy:  strings.TrimSpace(settings.HTTPSProxy),
		Ext:         req.Ext,
		Filter:      req.Filter,
	}
	data, _ := json.Marshal(payload)
	return string(data)
}

func copyExt(ext map[string]any) map[string]any {
	if len(ext) == 0 {
		return map[string]any{}
	}
	out := make(map[string]any, len(ext))
	for key, value := range ext {
		out[key] = value
	}
	return out
}

func stageKey(stage string, settings Settings, keyword string, channels, plugins []string, ext map[string]any) string {
	payload := struct {
		Stage      string         `json:"stage"`
		Keyword    string         `json:"keyword"`
		Channels   []string       `json:"channels,omitempty"`
		Plugins    []string       `json:"plugins,omitempty"`
		HTTPProxy  string         `json:"http_proxy"`
		HTTPSProxy string         `json:"https_proxy"`
		Ext        map[string]any `json:"ext,omitempty"`
	}{
		Stage:      stage,
		Keyword:    strings.TrimSpace(keyword),
		Channels:   channels,
		Plugins:    plugins,
		HTTPProxy:  strings.TrimSpace(settings.HTTPProxy),
		HTTPSProxy: strings.TrimSpace(settings.HTTPSProxy),
		Ext:        ext,
	}
	data, _ := json.Marshal(payload)
	return string(data)
}
