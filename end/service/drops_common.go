package service

import (
	"errors"
	"fmt"
	"net/url"
	"ohome/model"
	"path"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/6tail/lunar-go/calendar"
	"github.com/spf13/viper"
)

const (
	dropsUploadApplication = "upload"
	dropsPhotoRootDir      = "materials"
	dropsDefaultReminder   = "7,3,1,0"
	dropsItemReminderKey   = "drops.itemReminderDays"
	dropsEventReminderKey  = "drops.eventReminderDays"
	dropsMaxPhotoCount     = 3
)

type DropsOverview struct {
	TodayTodoCount     int                `json:"todayTodoCount"`
	ExpiringSoonCount  int                `json:"expiringSoonCount"`
	MonthEventCount    int                `json:"monthEventCount"`
	UnreadMessageCount int                `json:"unreadMessageCount"`
	RecentItems        []model.DropsItem  `json:"recentItems"`
	RecentEvents       []model.DropsEvent `json:"recentEvents"`
}

func normalizeDropsScope(scope string) string {
	switch strings.TrimSpace(strings.ToLower(scope)) {
	case model.DropsScopePersonal:
		return model.DropsScopePersonal
	default:
		return model.DropsScopeShared
	}
}

func normalizeDropsItemCategory(category string) string {
	return strings.TrimSpace(strings.ToLower(category))
}

func normalizeDropsEventType(eventType string) string {
	return strings.TrimSpace(strings.ToLower(eventType))
}

func normalizeDropsCalendarType(calendarType string) string {
	switch strings.TrimSpace(strings.ToLower(calendarType)) {
	case model.DropsCalendarLunar:
		return model.DropsCalendarLunar
	default:
		return model.DropsCalendarSolar
	}
}

func normalizeReminderDays(raw string) (string, []int, error) {
	if strings.TrimSpace(raw) == "" {
		raw = dropsDefaultReminder
	}
	set := map[int]struct{}{}
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		value, err := strconv.Atoi(part)
		if err != nil {
			return "", nil, fmt.Errorf("提醒规则格式错误: %s", part)
		}
		if value < 0 || value > 365 {
			return "", nil, fmt.Errorf("提醒天数必须在 0-365 之间: %d", value)
		}
		set[value] = struct{}{}
	}
	if len(set) == 0 {
		return "", nil, errors.New("提醒规则不能为空")
	}
	values := make([]int, 0, len(set))
	for value := range set {
		values = append(values, value)
	}
	sort.Slice(values, func(i, j int) bool { return values[i] > values[j] })
	parts := make([]string, 0, len(values))
	for _, value := range values {
		parts = append(parts, strconv.Itoa(value))
	}
	return strings.Join(parts, ","), values, nil
}

func configuredDropsItemReminderDays() (string, []int, error) {
	return normalizeReminderDays(strings.TrimSpace(viper.GetString(dropsItemReminderKey)))
}

func configuredDropsEventReminderDays() (string, []int, error) {
	return normalizeReminderDays(strings.TrimSpace(viper.GetString(dropsEventReminderKey)))
}

func parseDateOnlyInLocation(raw string, loc *time.Location) (*time.Time, error) {
	text := strings.TrimSpace(raw)
	if text == "" {
		return nil, nil
	}
	if loc == nil {
		loc = time.Local
	}
	parsed, err := time.ParseInLocation("2006-01-02", text, loc)
	if err != nil {
		return nil, errors.New("日期格式错误，应为 YYYY-MM-DD")
	}
	return &parsed, nil
}

func dropsPhotoFolder(category string, itemID uint) string {
	return "/" + path.Join(dropsPhotoRootDir, category, fmt.Sprintf("%d", itemID))
}

func dropsPhotoURL(filePath string) string {
	return "/api/v1/public/quarkFs/" + url.PathEscape(dropsUploadApplication) + "/files/stream?path=" + url.QueryEscape(filePath)
}

func dropsNormalizeQuarkPath(raw string) string {
	value := strings.TrimSpace(strings.ReplaceAll(raw, "\\", "/"))
	if value == "" {
		return "/"
	}
	if !strings.HasPrefix(value, "/") {
		value = "/" + value
	}
	return path.Clean(value)
}

func dropsStartOfDay(value time.Time, loc *time.Location) time.Time {
	if loc == nil {
		loc = value.Location()
	}
	current := value.In(loc)
	return time.Date(current.Year(), current.Month(), current.Day(), 0, 0, 0, 0, loc)
}

func dropsDaysUntil(now time.Time, target time.Time, loc *time.Location) int {
	start := dropsStartOfDay(now, loc)
	end := dropsStartOfDay(target, loc)
	return int(end.Sub(start).Hours() / 24)
}

func computeDropsEventNextOccurrence(event *model.DropsEvent, now time.Time, loc *time.Location) (*time.Time, error) {
	if event == nil {
		return nil, errors.New("事件不能为空")
	}
	if loc == nil {
		loc = now.Location()
	}
	switch normalizeDropsCalendarType(event.CalendarType) {
	case model.DropsCalendarLunar:
		return computeDropsLunarNextOccurrence(event, now, loc)
	default:
		return computeDropsSolarNextOccurrence(event, now, loc)
	}
}

func computeDropsSolarNextOccurrence(event *model.DropsEvent, now time.Time, loc *time.Location) (*time.Time, error) {
	if event.EventMonth < 1 || event.EventMonth > 12 || event.EventDay < 1 || event.EventDay > 31 {
		return nil, errors.New("公历日期无效")
	}
	start := dropsStartOfDay(now, loc)
	if !event.RepeatYearly {
		if event.EventYear <= 0 {
			return nil, errors.New("非循环公历日期必须填写年份")
		}
		candidate := time.Date(event.EventYear, time.Month(event.EventMonth), event.EventDay, 0, 0, 0, 0, loc)
		if candidate.Month() != time.Month(event.EventMonth) || candidate.Day() != event.EventDay {
			return nil, errors.New("公历日期无效")
		}
		if candidate.Before(start) {
			return nil, nil
		}
		return &candidate, nil
	}
	for year := start.Year(); year <= start.Year()+2; year++ {
		candidate := time.Date(year, time.Month(event.EventMonth), event.EventDay, 0, 0, 0, 0, loc)
		if candidate.Month() != time.Month(event.EventMonth) || candidate.Day() != event.EventDay {
			continue
		}
		if !candidate.Before(start) {
			return &candidate, nil
		}
	}
	return nil, nil
}

func computeDropsLunarNextOccurrence(event *model.DropsEvent, now time.Time, loc *time.Location) (*time.Time, error) {
	if event.EventMonth < 1 || event.EventMonth > 12 || event.EventDay < 1 || event.EventDay > 30 {
		return nil, errors.New("农历日期无效")
	}
	lunarMonth := event.EventMonth
	if event.IsLeapMonth {
		lunarMonth = -lunarMonth
	}
	start := dropsStartOfDay(now, loc)
	if !event.RepeatYearly {
		if event.EventYear <= 0 {
			return nil, errors.New("非循环农历日期必须填写年份")
		}
		return buildDropsLunarOccurrence(event.EventYear, lunarMonth, event.EventDay, start, loc)
	}

	currentLunar := calendar.NewSolarFromDate(start).GetLunar()
	currentLunarYear := currentLunar.GetYear()
	for year := currentLunarYear; year <= currentLunarYear+3; year++ {
		candidate, err := buildDropsLunarOccurrence(year, lunarMonth, event.EventDay, start, loc)
		if err != nil {
			continue
		}
		if candidate != nil {
			return candidate, nil
		}
	}
	return nil, nil
}

func buildDropsLunarOccurrence(year, lunarMonth, lunarDay int, start time.Time, loc *time.Location) (*time.Time, error) {
	lunarYear := calendar.NewLunarYear(year)
	if lunarMonth < 0 && lunarYear.GetLeapMonth() != -lunarMonth {
		return nil, errors.New("该年不存在对应闰月")
	}

	var occurrence *time.Time
	var panicErr any
	func() {
		defer func() {
			panicErr = recover()
		}()
		solar := calendar.NewLunarFromYmd(year, lunarMonth, lunarDay).GetSolar()
		candidate := time.Date(solar.GetYear(), time.Month(solar.GetMonth()), solar.GetDay(), 0, 0, 0, 0, loc)
		occurrence = &candidate
	}()
	if panicErr != nil {
		return nil, errors.New("农历日期无效")
	}
	if occurrence == nil {
		return nil, nil
	}
	if occurrence.Before(start) {
		return nil, nil
	}
	return occurrence, nil
}

func containsInt(items []int, target int) bool {
	for _, item := range items {
		if item == target {
			return true
		}
	}
	return false
}

func dropsItemCategoryLabel(category string) string {
	switch strings.TrimSpace(strings.ToLower(category)) {
	case model.DropsItemCategoryKitchen:
		return "厨房用品"
	case model.DropsItemCategoryFood:
		return "食品"
	case model.DropsItemCategoryMedicine:
		return "药品"
	case model.DropsItemCategoryClothing:
		return "衣物"
	case model.DropsItemCategoryOther:
		return "其他"
	default:
		if strings.TrimSpace(category) == "" {
			return "未分类"
		}
		return category
	}
}

func dropsEventTypeLabel(eventType string) string {
	switch strings.TrimSpace(strings.ToLower(eventType)) {
	case model.DropsEventTypeBirthday:
		return "生日"
	case model.DropsEventTypeAnniversary:
		return "纪念日"
	case model.DropsEventTypeCustom:
		return "自定义"
	default:
		if strings.TrimSpace(eventType) == "" {
			return "未分类"
		}
		return eventType
	}
}

func dropsCalendarTypeLabel(calendarType string) string {
	switch strings.TrimSpace(strings.ToLower(calendarType)) {
	case model.DropsCalendarLunar:
		return "农历"
	case model.DropsCalendarSolar:
		return "公历"
	default:
		if strings.TrimSpace(calendarType) == "" {
			return "未设置"
		}
		return calendarType
	}
}
