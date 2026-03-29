package service

import (
	"context"
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	"path"
	"strconv"
	"strings"
	"sync"
	"time"
)

// QuarkStreamResult holds the result of a proxied stream operation.
type QuarkStreamResult struct {
	Body          io.ReadCloser
	ContentLength int64
	ContentType   string
	StatusCode    int
	ContentRange  string
}

type QuarkProxyResponseMeta struct {
	ContentLength int64
	StatusCode    int
	ContentRange  string
}

type quarkDownloadTask struct {
	ID    int
	Start int64
	Size  int64
}

type quarkDownloadResult struct {
	ID   int
	Data []byte
}

type quarkStreamReadCloser struct {
	io.ReadCloser
	cancel context.CancelCauseFunc
	once   sync.Once
}

func (r *quarkStreamReadCloser) Close() error {
	var err error
	r.once.Do(func() {
		if r.cancel != nil {
			r.cancel(context.Canceled)
		}
		if r.ReadCloser != nil {
			err = r.ReadCloser.Close()
		}
	})
	return err
}

// parseRangeHeader parses an HTTP Range header and returns the byte offset and length.
// Returns (0, fileSize, nil) for empty or invalid headers (i.e. request the full file).
func parseRangeHeader(rangeHeader string, fileSize int64) (start, length int64, err error) {
	if strings.TrimSpace(rangeHeader) == "" {
		return 0, fileSize, nil
	}

	const prefix = "bytes="
	if !strings.HasPrefix(rangeHeader, prefix) {
		return 0, fileSize, nil
	}

	spec := strings.TrimPrefix(rangeHeader, prefix)
	// Only handle the first range in a multi-range header
	if idx := strings.IndexByte(spec, ','); idx >= 0 {
		spec = spec[:idx]
	}
	spec = strings.TrimSpace(spec)

	// Suffix range: "-500" means last 500 bytes
	if strings.HasPrefix(spec, "-") {
		suffix, parseErr := strconv.ParseInt(spec[1:], 10, 64)
		if parseErr != nil || suffix <= 0 {
			return 0, fileSize, nil
		}
		start = fileSize - suffix
		if start < 0 {
			start = 0
		}
		return start, fileSize - start, nil
	}

	dashIdx := strings.IndexByte(spec, '-')
	if dashIdx < 0 {
		return 0, fileSize, nil
	}

	start, err = strconv.ParseInt(spec[:dashIdx], 10, 64)
	if err != nil || start < 0 {
		return 0, fileSize, nil
	}
	if start >= fileSize {
		return 0, 0, fmt.Errorf("分片起始位置 %d 不能大于等于文件大小 %d", start, fileSize)
	}

	endStr := spec[dashIdx+1:]
	if endStr == "" {
		// "bytes=100-" means from 100 to end
		return start, fileSize - start, nil
	}

	end, parseErr := strconv.ParseInt(endStr, 10, 64)
	if parseErr != nil || end < start {
		return 0, fileSize, nil
	}
	if end >= fileSize {
		end = fileSize - 1
	}
	return start, end - start + 1, nil
}

func BuildQuarkProxyResponseMeta(fileSize int64, rangeHeader string) (QuarkProxyResponseMeta, error) {
	if fileSize == 0 {
		return QuarkProxyResponseMeta{
			ContentLength: 0,
			StatusCode:    http.StatusOK,
		}, nil
	}
	start, length, err := parseRangeHeader(rangeHeader, fileSize)
	if err != nil {
		return QuarkProxyResponseMeta{}, err
	}
	if length <= 0 {
		return QuarkProxyResponseMeta{}, fmt.Errorf("无效的范围参数：起始=%d 长度=%d 文件大小=%d", start, length, fileSize)
	}

	meta := QuarkProxyResponseMeta{
		ContentLength: length,
		StatusCode:    http.StatusOK,
	}
	if !(start == 0 && length == fileSize) {
		meta.StatusCode = http.StatusPartialContent
		meta.ContentRange = fmt.Sprintf("bytes %d-%d/%d", start, start+length-1, fileSize)
	}
	return meta, nil
}

func buildQuarkDownloadTasks(start, length, partSize int64) []quarkDownloadTask {
	if length <= 0 {
		return nil
	}
	if partSize <= 0 || length <= partSize {
		return []quarkDownloadTask{{ID: 0, Start: start, Size: length}}
	}

	maxPart := int((length + partSize - 1) / partSize)
	tasks := make([]quarkDownloadTask, 0, maxPart)
	pos := start
	remaining := length

	for i := 0; remaining > 0; i++ {
		size := partSize
		remainder := length % partSize
		minSize := partSize / 2
		switch i {
		case 0:
			if remainder > 0 {
				if remainder < minSize && minSize > 0 {
					size = minSize
				} else {
					size = remainder
				}
			}
		case 1:
			if remainder > 0 && remainder < minSize && minSize > 0 {
				size += remainder - minSize
			}
		}
		if size <= 0 || size > remaining {
			size = remaining
		}
		tasks = append(tasks, quarkDownloadTask{
			ID:    i,
			Start: pos,
			Size:  size,
		})
		pos += size
		remaining -= size
	}
	return tasks
}

func parseContentRangeStart(contentRange string) (int64, int64, error) {
	contentRange = strings.TrimSpace(contentRange)
	if !strings.HasPrefix(contentRange, "bytes ") {
		return 0, 0, fmt.Errorf("无效的 Content-Range：%q", contentRange)
	}

	rangePart := strings.TrimSpace(strings.TrimPrefix(contentRange, "bytes "))
	segments := strings.SplitN(rangePart, "/", 2)
	if len(segments) != 2 {
		return 0, 0, fmt.Errorf("无效的 Content-Range：%q", contentRange)
	}

	bounds := strings.SplitN(strings.TrimSpace(segments[0]), "-", 2)
	if len(bounds) != 2 {
		return 0, 0, fmt.Errorf("Content-Range 边界无效：%q", contentRange)
	}

	start, err := strconv.ParseInt(strings.TrimSpace(bounds[0]), 10, 64)
	if err != nil {
		return 0, 0, err
	}
	end, err := strconv.ParseInt(strings.TrimSpace(bounds[1]), 10, 64)
	if err != nil {
		return 0, 0, err
	}
	if end < start {
		return 0, 0, fmt.Errorf("Content-Range 边界无效：%q", contentRange)
	}
	return start, end, nil
}

func validateQuarkRangeResponse(resp *http.Response, expectedStart, expectedLength int64) error {
	if resp == nil {
		return errors.New("上游响应为空")
	}
	if expectedLength <= 0 {
		return fmt.Errorf("期望长度无效：%d", expectedLength)
	}
	if resp.StatusCode != http.StatusPartialContent {
		return fmt.Errorf("上游未正确处理范围请求：状态码=%d", resp.StatusCode)
	}

	contentRange := strings.TrimSpace(resp.Header.Get("Content-Range"))
	if contentRange == "" {
		if resp.ContentLength > 0 && resp.ContentLength != expectedLength {
			return fmt.Errorf("上游 Content-Length 不符合预期：期望=%d，实际=%d", expectedLength, resp.ContentLength)
		}
		return nil
	}

	start, end, err := parseContentRangeStart(contentRange)
	if err != nil {
		return err
	}
	if start != expectedStart {
		return fmt.Errorf("上游返回的范围起点不符合预期：期望=%d，实际=%d", expectedStart, start)
	}
	if end-start+1 != expectedLength {
		return fmt.Errorf("上游返回的范围长度不符合预期：期望=%d，实际=%d", expectedLength, end-start+1)
	}
	return nil
}

func isQuarkRangeRetryable(err error) bool {
	if err == nil {
		return false
	}
	return !errors.Is(err, context.Canceled) && !errors.Is(err, context.DeadlineExceeded)
}

func quarkRangeRetryDelay(attempt int) time.Duration {
	if attempt < 1 {
		attempt = 1
	}
	return time.Duration(attempt) * 250 * time.Millisecond
}

func (c *quarkClient) readChunkRange(ctx context.Context, downloadURL string, start int64, dst []byte) (int64, error) {
	if len(dst) == 0 {
		return 0, nil
	}

	rangeHeader := fmt.Sprintf("bytes=%d-%d", start, start+int64(len(dst))-1)
	resp, err := c.openDownloadStream(ctx, downloadURL, rangeHeader)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if err := validateQuarkRangeResponse(resp, start, int64(len(dst))); err != nil {
		return 0, err
	}

	n, err := io.ReadFull(resp.Body, dst)
	return int64(n), err
}

func (c *quarkClient) downloadChunkWithRetry(
	ctx context.Context,
	downloadURL string,
	task quarkDownloadTask,
	cfg quarkStreamConfig,
) ([]byte, error) {
	buf := make([]byte, task.Size)
	offset := int64(0)

	for attempt := 0; attempt <= cfg.ChunkMaxRetries; attempt++ {
		if ctx.Err() != nil {
			if cause := context.Cause(ctx); cause != nil {
				return nil, cause
			}
			return nil, ctx.Err()
		}

		n, err := c.readChunkRange(ctx, downloadURL, task.Start+offset, buf[offset:])
		offset += n
		if err == nil && offset == task.Size {
			return buf, nil
		}
		if err == nil {
			err = io.ErrUnexpectedEOF
		}
		if offset >= task.Size {
			return buf, nil
		}
		if attempt >= cfg.ChunkMaxRetries || !isQuarkRangeRetryable(err) {
			return nil, fmt.Errorf("分片 %d 下载失败，已完成 %d/%d 字节：%w", task.ID, offset, task.Size, err)
		}

		logQuarkWarnf(
			"[quarkFs:stream] retry chunk id=%d range=%d-%d progress=%d/%d attempt=%d/%d err=%v",
			task.ID,
			task.Start,
			task.Start+task.Size-1,
			offset,
			task.Size,
			attempt+1,
			cfg.ChunkMaxRetries,
			err,
		)

		select {
		case <-ctx.Done():
			if cause := context.Cause(ctx); cause != nil {
				return nil, cause
			}
			return nil, ctx.Err()
		case <-time.After(quarkRangeRetryDelay(attempt + 1)):
		}
	}

	return nil, fmt.Errorf("分片 %d 下载重试次数已耗尽", task.ID)
}

func (c *quarkClient) streamDownloadInOrder(
	ctx context.Context,
	cancel context.CancelCauseFunc,
	downloadURL string,
	tasks []quarkDownloadTask,
	cfg quarkStreamConfig,
	writer *io.PipeWriter,
) {
	defer func() {
		if cause := context.Cause(ctx); cause != nil && !errors.Is(cause, context.Canceled) {
			_ = writer.CloseWithError(cause)
			return
		}
		_ = writer.Close()
	}()
	defer cancel(nil)

	if len(tasks) == 0 {
		return
	}

	workerCount := min(cfg.Concurrency, len(tasks))
	if workerCount <= 0 {
		workerCount = 1
	}

	logQuarkWarnf(
		"[quarkFs:stream] concurrent proxy start chunks=%d concurrency=%d partSize=%d retries=%d range=%d-%d",
		len(tasks),
		workerCount,
		cfg.PartSize,
		cfg.ChunkMaxRetries,
		tasks[0].Start,
		tasks[len(tasks)-1].Start+tasks[len(tasks)-1].Size-1,
	)

	taskCh := make(chan quarkDownloadTask)
	resultCh := make(chan quarkDownloadResult, workerCount)

	var (
		wg       sync.WaitGroup
		errOnce  sync.Once
		firstErr error
	)

	fail := func(err error) {
		if err == nil {
			return
		}
		errOnce.Do(func() {
			firstErr = err
			cancel(err)
		})
	}

	for i := 0; i < workerCount; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-ctx.Done():
					return
				case task, ok := <-taskCh:
					if !ok {
						return
					}
					data, err := c.downloadChunkWithRetry(ctx, downloadURL, task, cfg)
					if err != nil {
						fail(err)
						return
					}
					select {
					case <-ctx.Done():
						return
					case resultCh <- quarkDownloadResult{ID: task.ID, Data: data}:
					}
				}
			}
		}()
	}

	go func() {
		defer close(taskCh)
		for _, task := range tasks {
			select {
			case <-ctx.Done():
				return
			case taskCh <- task:
			}
		}
	}()

	go func() {
		wg.Wait()
		close(resultCh)
	}()

	pending := make(map[int][]byte, workerCount)
	nextID := 0
	completed := 0

	for completed < len(tasks) {
		select {
		case <-ctx.Done():
			if firstErr != nil {
				return
			}
			if cause := context.Cause(ctx); cause != nil {
				fail(cause)
				return
			}
			fail(ctx.Err())
			return
		case result, ok := <-resultCh:
			if !ok {
				if firstErr != nil {
					return
				}
				if completed < len(tasks) {
					fail(io.ErrUnexpectedEOF)
				}
				return
			}

			pending[result.ID] = result.Data
			for {
				data, exists := pending[nextID]
				if !exists {
					break
				}
				if _, err := writer.Write(data); err != nil {
					fail(err)
					return
				}
				delete(pending, nextID)
				nextID++
				completed++
			}
		}
	}

	logQuarkWarnf(
		"[quarkFs:stream] concurrent proxy done chunks=%d concurrency=%d",
		len(tasks),
		workerCount,
	)
}

func (c *quarkClient) openSingleProxyStream(
	ctx context.Context,
	downloadURL string,
	reqStart int64,
	reqLength int64,
	fileSize int64,
	contentType string,
) (*QuarkStreamResult, error) {
	isPartial := !(reqStart == 0 && reqLength == fileSize)
	rangeHeader := ""
	if isPartial {
		rangeHeader = fmt.Sprintf("bytes=%d-%d", reqStart, reqStart+reqLength-1)
	}

	resp, err := c.openDownloadStream(ctx, downloadURL, rangeHeader)
	if err != nil {
		return nil, err
	}
	upstreamCT := strings.TrimSpace(resp.Header.Get("Content-Type"))
	if upstreamCT != "" {
		contentType = upstreamCT
	}

	result := &QuarkStreamResult{
		Body:          resp.Body,
		ContentLength: reqLength,
		ContentType:   contentType,
		StatusCode:    http.StatusOK,
	}
	if isPartial {
		result.StatusCode = http.StatusPartialContent
		result.ContentRange = fmt.Sprintf("bytes %d-%d/%d", reqStart, reqStart+reqLength-1, fileSize)
	}
	return result, nil
}

// openProxyStream proxies the requested range from the upstream download URL.
// For large ranges, it follows OpenList's approach: concurrent upstream range
// downloads plus ordered output to the player.
func (c *quarkClient) openProxyStream(
	ctx context.Context,
	downloadURL string,
	fileSize int64,
	rangeHeader string,
	filename string,
) (*QuarkStreamResult, error) {
	reqStart, reqLength, err := parseRangeHeader(rangeHeader, fileSize)
	if err != nil {
		return nil, err
	}
	if reqLength <= 0 {
		return nil, fmt.Errorf("无效的范围参数：起始=%d 长度=%d 文件大小=%d", reqStart, reqLength, fileSize)
	}

	isPartial := !(reqStart == 0 && reqLength == fileSize)
	cfg := loadQuarkStreamConfig()
	tasks := buildQuarkDownloadTasks(reqStart, reqLength, cfg.PartSize)

	// Determine content type from filename extension
	contentType := mime.TypeByExtension(path.Ext(filename))
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	if len(tasks) <= 1 || cfg.Concurrency <= 1 || cfg.PartSize <= 0 {
		return c.openSingleProxyStream(ctx, downloadURL, reqStart, reqLength, fileSize, contentType)
	}

	streamCtx, cancel := context.WithCancelCause(ctx)
	reader, writer := io.Pipe()
	go c.streamDownloadInOrder(streamCtx, cancel, downloadURL, tasks, cfg, writer)

	result := &QuarkStreamResult{
		Body:          &quarkStreamReadCloser{ReadCloser: reader, cancel: cancel},
		ContentLength: reqLength,
		ContentType:   contentType,
		StatusCode:    http.StatusOK,
	}
	if isPartial {
		result.StatusCode = http.StatusPartialContent
		result.ContentRange = fmt.Sprintf("bytes %d-%d/%d", reqStart, reqStart+reqLength-1, fileSize)
	}
	return result, nil
}
