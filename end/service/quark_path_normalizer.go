package service

import (
	"path"
	"strconv"
	"strings"
)

func normalizeQuarkRelativeStorePath(raw string) string {
	segments := splitNormalizedQuarkPathSegments(raw)
	if len(segments) == 0 {
		return ""
	}
	return path.Join(segments...)
}

func normalizeConfiguredQuarkRootPath(raw string) string {
	relative := normalizeQuarkRelativeStorePath(raw)
	if relative != "" {
		return "/" + relative
	}

	trimmed := strings.TrimSpace(strings.ReplaceAll(raw, "\\", "/"))
	if trimmed == "" {
		return ""
	}
	return "/"
}

func normalizeQuarkConfigRootPathValue(raw string) string {
	relative := normalizeQuarkRelativeStorePath(raw)
	if relative != "" {
		return relative
	}

	trimmed := strings.TrimSpace(strings.ReplaceAll(raw, "\\", "/"))
	if trimmed == "" {
		return ""
	}
	return "/"
}

func buildQuarkUserScopedRootPath(raw string, userID uint) string {
	base := normalizeConfiguredQuarkRootPath(raw)
	if userID == 0 {
		if base != "" {
			return base
		}
		return "/"
	}

	userSegment := strings.TrimSpace(strconv.FormatUint(uint64(userID), 10))
	if userSegment == "" {
		if base != "" {
			return base
		}
		return "/"
	}

	if base == "" || base == "/" {
		return "/" + userSegment
	}
	return normalizeConfiguredQuarkRootPath(path.Join(base, userSegment))
}

func resolveQuarkRootPathForUser(application, raw string, userID uint) string {
	base := normalizeConfiguredQuarkRootPath(raw)
	if !shouldUseUserScopedQuarkRoot(application) {
		if base != "" {
			return base
		}
		return "/"
	}
	return buildQuarkUserScopedRootPath(raw, userID)
}

func shouldUseUserScopedQuarkRoot(application string) bool {
	return !strings.EqualFold(strings.TrimSpace(application), "upload")
}

func splitNormalizedQuarkPathSegments(raw string) []string {
	trimmed := strings.TrimSpace(strings.ReplaceAll(raw, "\\", "/"))
	if trimmed == "" {
		return nil
	}
	if !strings.HasPrefix(trimmed, "/") {
		trimmed = "/" + trimmed
	}

	cleaned := path.Clean(trimmed)
	if cleaned == "." || cleaned == "/" {
		return nil
	}

	parts := strings.Split(strings.Trim(cleaned, "/"), "/")
	segments := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" || part == "." {
			continue
		}
		segments = append(segments, part)
	}

	if len(segments) > 0 && strings.EqualFold(segments[0], "quark") {
		segments = segments[1:]
	}
	return segments
}
