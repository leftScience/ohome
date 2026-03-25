package service

import (
	"context"
	"fmt"
	"io"
	"mime"
	"net/http"
	"path"
	"strconv"
	"strings"
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
		return 0, 0, fmt.Errorf("range start %d >= file size %d", start, fileSize)
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
		return QuarkProxyResponseMeta{}, fmt.Errorf("invalid range: start=%d length=%d fileSize=%d", start, length, fileSize)
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

// openProxyStream proxies the requested range from the upstream download URL
// using a single HTTP connection so the player can read bytes in order.
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
		return nil, fmt.Errorf("invalid range: start=%d length=%d fileSize=%d", reqStart, reqLength, fileSize)
	}

	isPartial := !(reqStart == 0 && reqLength == fileSize)

	// Determine content type from filename extension
	contentType := mime.TypeByExtension(path.Ext(filename))
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	buildResult := func(body io.ReadCloser, ct string) *QuarkStreamResult {
		if ct != "" {
			contentType = ct
		}
		result := &QuarkStreamResult{
			Body:          body,
			ContentLength: reqLength,
			ContentType:   contentType,
		}
		if isPartial {
			result.StatusCode = http.StatusPartialContent
			result.ContentRange = fmt.Sprintf("bytes %d-%d/%d", reqStart, reqStart+reqLength-1, fileSize)
		} else {
			result.StatusCode = http.StatusOK
		}
		return result
	}

	rh := ""
	if isPartial {
		rh = fmt.Sprintf("bytes=%d-%d", reqStart, reqStart+reqLength-1)
	}
	resp, err := c.openDownloadStream(ctx, downloadURL, rh)
	if err != nil {
		return nil, err
	}
	upstreamCT := resp.Header.Get("Content-Type")
	return buildResult(resp.Body, upstreamCT), nil
}
