package updater

import (
	"regexp"
	"strconv"
)

var versionPartRegexp = regexp.MustCompile(`\d+`)

func CompareVersions(left string, right string) int {
	leftParts := extractVersionParts(left)
	rightParts := extractVersionParts(right)
	length := len(leftParts)
	if len(rightParts) > length {
		length = len(rightParts)
	}
	for i := 0; i < length; i++ {
		lv := 0
		if i < len(leftParts) {
			lv = leftParts[i]
		}
		rv := 0
		if i < len(rightParts) {
			rv = rightParts[i]
		}
		if lv == rv {
			continue
		}
		if lv > rv {
			return 1
		}
		return -1
	}
	return 0
}

func extractVersionParts(value string) []int {
	matches := versionPartRegexp.FindAllString(value, -1)
	if len(matches) == 0 {
		return nil
	}
	result := make([]int, 0, len(matches))
	for _, match := range matches {
		if parsed, err := strconv.Atoi(match); err == nil {
			result = append(result, parsed)
		}
	}
	return result
}
