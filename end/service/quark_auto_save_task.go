package service

import (
	"context"
	"errors"
	"fmt"
	"ohome/model"
	"ohome/service/dto"
	"strconv"
	"strings"
	"time"
)

type QuarkAutoSaveTaskService struct {
	BaseService
}

const quarkTransferPrecheckTimeout = 30 * time.Second

func (s *QuarkAutoSaveTaskService) GetByID(iCommonIDDTO *dto.CommonIDDTO, ownerUserID uint) (model.QuarkAutoSaveTask, error) {
	return quarkAutoSaveTaskDao.GetByID(iCommonIDDTO.ID, ownerUserID)
}

func (s *QuarkAutoSaveTaskService) GetList(listDTO *dto.QuarkAutoSaveTaskListDTO, ownerUserID uint) ([]model.QuarkAutoSaveTask, int64, error) {
	return quarkAutoSaveTaskDao.GetList(listDTO, ownerUserID)
}

func (s *QuarkAutoSaveTaskService) GetEnabledTasks() ([]model.QuarkAutoSaveTask, error) {
	return quarkAutoSaveTaskDao.GetEnabledTasks()
}

func (s *QuarkAutoSaveTaskService) AddOrUpdate(updateDTO *dto.QuarkAutoSaveTaskUpdateDTO, ownerUserID uint) error {
	updateDTO.TaskName = strings.TrimSpace(updateDTO.TaskName)
	updateDTO.ShareURL = strings.TrimSpace(updateDTO.ShareURL)
	updateDTO.SavePath = stripQuarkPrefixForStore(updateDTO.SavePath)
	updateDTO.ScheduleType = strings.ToLower(strings.TrimSpace(updateDTO.ScheduleType))
	updateDTO.RunTime = strings.TrimSpace(updateDTO.RunTime)
	updateDTO.RunWeek = strings.TrimSpace(updateDTO.RunWeek)

	if updateDTO.TaskName == "" || updateDTO.ShareURL == "" || updateDTO.SavePath == "" {
		return errors.New("任务名称、分享链接和保存路径不能为空")
	}
	if updateDTO.ScheduleType != "daily" && updateDTO.ScheduleType != "weekly" {
		return fmt.Errorf("调度类型仅支持按天或按周")
	}

	h, m, ok := parseHHMM(updateDTO.RunTime)
	if !ok {
		return fmt.Errorf("运行时间格式错误，需要 HH:mm（例如 08:30）")
	}
	updateDTO.RunTime = fmt.Sprintf("%02d:%02d", h, m)

	if updateDTO.ScheduleType == "daily" {
		updateDTO.RunWeek = ""
	} else {
		if len(parseRunWeek(updateDTO.RunWeek)) == 0 {
			return fmt.Errorf("按周模式必须选择周几（例如 1,3,5）")
		}
	}

	return quarkAutoSaveTaskDao.AddOrUpdate(updateDTO, ownerUserID)
}

func (s *QuarkAutoSaveTaskService) DeleteByID(iCommonIDDTO *dto.CommonIDDTO, ownerUserID uint) error {
	if _, err := quarkAutoSaveTaskDao.GetByID(iCommonIDDTO.ID, ownerUserID); err != nil {
		return err
	}
	return quarkAutoSaveTaskDao.Delete(iCommonIDDTO.ID, ownerUserID)
}

func (s *QuarkAutoSaveTaskService) RunOnce(task model.QuarkAutoSaveTask, ownerUserID uint) (model.QuarkTransferTask, error) {
	return (&QuarkTransferTaskService{}).SubmitSyncManualTask(task, ownerUserID)
}

func (s *QuarkAutoSaveTaskService) SubmitScheduled(task model.QuarkAutoSaveTask) (model.QuarkTransferTask, error) {
	return (&QuarkTransferTaskService{}).SubmitSyncScheduleTask(task)
}

func (s *QuarkAutoSaveTaskService) TransferOnce(transferDTO *dto.QuarkAutoSaveTransferDTO, ownerUserID uint) (model.QuarkTransferTask, error) {
	return (&QuarkTransferTaskService{}).SubmitSearchManualTransfer(transferDTO, ownerUserID)
}

func executeQuarkTransfer(ctx context.Context, task quarkSaveTask) (quarkSaveResult, error) {
	cookie, err := loadPrimaryQuarkCookie()
	if err != nil {
		return quarkSaveResult{Status: "fail", Message: err.Error()}, err
	}

	client := newQuarkClient(cookie)
	if err := client.initAccount(ctx); err != nil {
		return quarkSaveResult{Status: "fail", Message: err.Error()}, err
	}

	return client.saveFromShare(ctx, task)
}

func precheckQuarkTransfer(task quarkSaveTask) error {
	ctx, cancel := context.WithTimeout(context.Background(), quarkTransferPrecheckTimeout)
	defer cancel()

	cookie, err := loadPrimaryQuarkCookie()
	if err != nil {
		return err
	}

	client := newQuarkClient(cookie)
	if err := client.initAccount(ctx); err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return errors.New("转存校验超时，请稍后重试")
		}
		return err
	}

	pwdID, passcode, pdirFid, err := extractShareParams(task.ShareURL)
	if err != nil {
		return err
	}

	stoken, err := client.getStoken(ctx, pwdID, passcode)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return errors.New("转存校验超时，请稍后重试")
		}
		return err
	}

	saveRootPath := buildQuarkSavePath(task.SavePath)
	saveRootFid, err := client.ensurePathFid(ctx, saveRootPath)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return errors.New("转存校验超时，请稍后重试")
		}
		return err
	}

	if err := client.validateShareAccess(ctx, pwdID, stoken, pdirFid); err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return errors.New("转存校验超时，请稍后重试")
		}
		return err
	}

	if err := client.validateDirAccess(ctx, saveRootFid); err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return errors.New("转存校验超时，请稍后重试")
		}
		return err
	}

	return nil
}

func (s *QuarkAutoSaveTaskService) ShouldRunNow(now time.Time, task model.QuarkAutoSaveTask) bool {
	if !task.Enabled {
		return false
	}

	h, m, ok := parseHHMM(task.RunTime)
	if !ok {
		return false
	}

	scheduleType := strings.ToLower(strings.TrimSpace(task.ScheduleType))
	if scheduleType != "daily" && scheduleType != "weekly" {
		return false
	}

	if scheduleType == "weekly" {
		wd := int(now.Weekday())
		if wd == 0 {
			wd = 7
		}
		if !parseRunWeek(task.RunWeek)[wd] {
			return false
		}
	}

	// 只在目标分钟触发（定时器每分钟扫描一次）
	if now.Hour() != h || now.Minute() != m {
		return false
	}

	// 避免同一分钟重复执行
	if task.LastRunAt != nil {
		lr := task.LastRunAt.In(now.Location())
		if lr.Year() == now.Year() &&
			lr.Month() == now.Month() &&
			lr.Day() == now.Day() &&
			lr.Hour() == now.Hour() &&
			lr.Minute() == now.Minute() {
			return false
		}
	}

	return true
}

func stripQuarkPrefixForStore(path string) string {
	return normalizeQuarkRelativeStorePath(path)
}

func parseHHMM(s string) (int, int, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0, 0, false
	}
	parts := strings.Split(s, ":")
	if len(parts) != 2 {
		return 0, 0, false
	}
	h, err1 := strconv.Atoi(strings.TrimSpace(parts[0]))
	m, err2 := strconv.Atoi(strings.TrimSpace(parts[1]))
	if err1 != nil || err2 != nil {
		return 0, 0, false
	}
	if h < 0 || h > 23 || m < 0 || m > 59 {
		return 0, 0, false
	}
	return h, m, true
}

func parseRunWeek(s string) map[int]bool {
	res := map[int]bool{}
	for _, p := range strings.Split(s, ",") {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		switch p {
		case "1", "2", "3", "4", "5", "6", "7":
			res[int(p[0]-'0')] = true
		}
	}
	return res
}
