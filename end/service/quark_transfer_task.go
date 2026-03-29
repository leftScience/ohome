package service

import (
	"context"
	"errors"
	"ohome/global"
	"ohome/model"
	"ohome/service/dto"
	"strings"
	"time"
)

const quarkTransferTaskTimeout = 15 * time.Minute

type QuarkTransferTaskService struct {
	BaseService
}

type quarkTransferTaskSubmission struct {
	displayName  string
	shareURL     string
	savePath     string
	application  string
	sourceType   string
	renameTo     string
	sourceTaskID *uint
	ownerUserID  uint
}

func (s *QuarkTransferTaskService) GetList(listDTO *dto.QuarkTransferTaskListDTO, ownerUserID uint) ([]model.QuarkTransferTask, int64, error) {
	listDTO.Status = strings.TrimSpace(listDTO.Status)
	listDTO.SourceType = strings.TrimSpace(listDTO.SourceType)
	return quarkTransferTaskDao.GetList(listDTO, ownerUserID)
}

func (s *QuarkTransferTaskService) DeleteByID(iCommonIDDTO *dto.CommonIDDTO, ownerUserID uint) error {
	if _, err := quarkTransferTaskDao.GetByID(iCommonIDDTO.ID, ownerUserID); err != nil {
		return err
	}
	if err := quarkTransferTaskDao.Delete(iCommonIDDTO.ID, ownerUserID); err != nil {
		return err
	}
	return nil
}

func (s *QuarkTransferTaskService) RecoverInterruptedTasks() error {
	recovered, err := quarkTransferTaskDao.RecoverInterruptedTasks(time.Now())
	if err != nil {
		return err
	}
	if recovered > 0 && global.Logger != nil {
		global.Logger.Warnf("Recovered %d interrupted quark transfer task(s)", recovered)
	}
	return nil
}

func (s *QuarkTransferTaskService) SubmitSearchManualTransfer(transferDTO *dto.QuarkAutoSaveTransferDTO, ownerUserID uint) (model.QuarkTransferTask, error) {
	shareURL := strings.TrimSpace(transferDTO.ShareURL)
	savePath := stripQuarkPrefixForStore(transferDTO.SavePath)
	if shareURL == "" || savePath == "" {
		return model.QuarkTransferTask{}, errors.New("分享链接和保存路径不能为空")
	}

	displayName := strings.TrimSpace(transferDTO.ResourceName)
	if displayName == "" {
		displayName = shareURL
	}

	if err := precheckQuarkTransfer(quarkSaveTask{
		TaskName: displayName,
		ShareURL: shareURL,
		SavePath: savePath,
	}); err != nil {
		return model.QuarkTransferTask{}, err
	}

	return s.submit(quarkTransferTaskSubmission{
		displayName: displayName,
		shareURL:    shareURL,
		savePath:    savePath,
		application: strings.TrimSpace(transferDTO.Application),
		sourceType:  model.QuarkTransferTaskSourceSearchManual,
		renameTo:    displayName,
		ownerUserID: ownerUserID,
	})
}

func (s *QuarkTransferTaskService) SubmitSyncManualTask(task model.QuarkAutoSaveTask, ownerUserID uint) (model.QuarkTransferTask, error) {
	return s.submitSyncTask(task, model.QuarkTransferTaskSourceSyncManual, ownerUserID)
}

func (s *QuarkTransferTaskService) SubmitSyncScheduleTask(task model.QuarkAutoSaveTask) (model.QuarkTransferTask, error) {
	return s.submitSyncTask(task, model.QuarkTransferTaskSourceSyncSchedule, task.OwnerUserID)
}

func (s *QuarkTransferTaskService) submitSyncTask(task model.QuarkAutoSaveTask, sourceType string, ownerUserID uint) (model.QuarkTransferTask, error) {
	shareURL := strings.TrimSpace(task.ShareURL)
	savePath := stripQuarkPrefixForStore(task.SavePath)
	if shareURL == "" || savePath == "" {
		return model.QuarkTransferTask{}, errors.New("分享链接和保存路径不能为空")
	}

	displayName := strings.TrimSpace(task.TaskName)
	if displayName == "" {
		displayName = shareURL
	}

	sourceTaskID := task.ID
	return s.submit(quarkTransferTaskSubmission{
		displayName:  displayName,
		shareURL:     shareURL,
		savePath:     savePath,
		sourceType:   sourceType,
		sourceTaskID: &sourceTaskID,
		ownerUserID:  ownerUserID,
	})
}

func (s *QuarkTransferTaskService) submit(submission quarkTransferTaskSubmission) (model.QuarkTransferTask, error) {
	submittedAt := time.Now()
	transferTask := model.QuarkTransferTask{
		OwnerUserID:  submission.ownerUserID,
		DisplayName:  submission.displayName,
		ShareURL:     submission.shareURL,
		SavePath:     submission.savePath,
		Application:  submission.application,
		SourceType:   submission.sourceType,
		SourceTaskID: submission.sourceTaskID,
		Status:       model.QuarkTransferTaskStatusQueued,
	}

	if err := quarkTransferTaskDao.Create(&transferTask, submission.sourceTaskID, submittedAt); err != nil {
		return model.QuarkTransferTask{}, err
	}

	if err := getOrCreateQuarkTransferTaskExecutor().enqueue(quarkTransferTaskExecution{
		task: transferTask,
		saveTask: quarkSaveTask{
			ID:               transferTask.ID,
			TaskName:         transferTask.DisplayName,
			ShareURL:         transferTask.ShareURL,
			SavePath:         transferTask.SavePath,
			RenameTopLevelTo: submission.renameTo,
		},
	}); err != nil {
		s.markTaskSubmitFailed(transferTask, err)
		return model.QuarkTransferTask{}, err
	}

	return transferTask, nil
}

func (s *QuarkTransferTaskService) markTaskSubmitFailed(task model.QuarkTransferTask, err error) {
	finishedAt := time.Now()
	task.Status = model.QuarkTransferTaskStatusFailed
	task.ResultMessage = strings.TrimSpace(err.Error())
	task.SavedCount = 0
	task.FinishedAt = &finishedAt
	if task.ResultMessage == "" {
		task.ResultMessage = quarkTransferTaskQueueFullMessage
	}

	if updateErr := quarkTransferTaskDao.UpdateTaskResult(task.ID, map[string]any{
		"status":         model.QuarkTransferTaskStatusFailed,
		"result_message": task.ResultMessage,
		"saved_count":    0,
		"finished_at":    finishedAt,
	}); updateErr != nil {
		if global.Logger != nil {
			global.Logger.Errorf("Quark Transfer Task Queue Reject Update Error: #%d %s", task.ID, updateErr.Error())
		}
		return
	}

	if notifyErr := (&AppMessageService{}).SaveQuarkTransferResult(task); notifyErr != nil && global.Logger != nil {
		global.Logger.Errorf("Quark Transfer Task Queue Reject Message Error: #%d %s", task.ID, notifyErr.Error())
	}
	if global.Logger != nil {
		global.Logger.Warnf("Quark Transfer Task Queue Reject: #%d %s", task.ID, task.ResultMessage)
	}
}

func (s *QuarkTransferTaskService) runTransferTask(
	task model.QuarkTransferTask,
	saveTask quarkSaveTask,
	execute quarkTransferExecuteFunc,
) {
	startedAt := time.Now()
	started, err := quarkTransferTaskDao.MarkProcessing(task.ID, startedAt)
	if err != nil {
		if global.Logger != nil {
			global.Logger.Errorf("Quark Transfer Task Start Update Error: #%d %s", task.ID, err.Error())
		}
		return
	}
	if !started {
		if global.Logger != nil {
			global.Logger.Warnf("Quark Transfer Task Skipped: #%d status is no longer queued", task.ID)
		}
		return
	}

	task.Status = model.QuarkTransferTaskStatusProcessing
	task.StartedAt = &startedAt
	task.FinishedAt = nil
	task.ResultMessage = ""
	task.SavedCount = 0

	if execute == nil {
		execute = executeQuarkTransfer
	}
	if global.Logger != nil {
		global.Logger.Infof("Quark Transfer Task Start: #%d %s", task.ID, saveTask.TaskName)
	}

	ctx, cancel := context.WithTimeout(context.Background(), quarkTransferTaskTimeout)
	defer cancel()

	result, err := execute(ctx, saveTask)
	finishedAt := time.Now()
	updates := map[string]any{
		"finished_at": finishedAt,
		"saved_count": 0,
	}

	if err != nil {
		task.Status = model.QuarkTransferTaskStatusFailed
		task.ResultMessage = formatQuarkTransferFailureMessage(result, err)
		task.SavedCount = 0
		task.FinishedAt = &finishedAt
		updates["status"] = model.QuarkTransferTaskStatusFailed
		updates["result_message"] = task.ResultMessage
		if updateErr := quarkTransferTaskDao.UpdateTaskResult(task.ID, updates); updateErr != nil && global.Logger != nil {
			global.Logger.Errorf("Quark Transfer Task Update Error: #%d %s", task.ID, updateErr.Error())
		}
		if notifyErr := (&AppMessageService{}).SaveQuarkTransferResult(task); notifyErr != nil && global.Logger != nil {
			global.Logger.Errorf("Quark Transfer Task Message Error: #%d %s", task.ID, notifyErr.Error())
		}
		if global.Logger != nil {
			global.Logger.Errorf("Quark Transfer Task Failed: #%d %s", task.ID, err.Error())
		}
		return
	}

	task.Status = model.QuarkTransferTaskStatusSuccess
	task.ResultMessage = strings.TrimSpace(result.Message)
	task.SavedCount = result.SavedCount
	task.FinishedAt = &finishedAt
	updates["status"] = model.QuarkTransferTaskStatusSuccess
	updates["result_message"] = task.ResultMessage
	updates["saved_count"] = result.SavedCount
	if updateErr := quarkTransferTaskDao.UpdateTaskResult(task.ID, updates); updateErr != nil && global.Logger != nil {
		global.Logger.Errorf("Quark Transfer Task Update Error: #%d %s", task.ID, updateErr.Error())
	}
	if notifyErr := (&AppMessageService{}).SaveQuarkTransferResult(task); notifyErr != nil && global.Logger != nil {
		global.Logger.Errorf("Quark Transfer Task Message Error: #%d %s", task.ID, notifyErr.Error())
	}
	if global.Logger != nil {
		global.Logger.Infof("Quark Transfer Task Done: #%d %s", task.ID, result.Message)
	}
}

func formatQuarkTransferFailureMessage(result quarkSaveResult, err error) string {
	message := strings.TrimSpace(result.Message)
	if message == "" && err != nil {
		message = strings.TrimSpace(err.Error())
	}
	if message == "" {
		return "任务失败"
	}
	if strings.HasPrefix(message, "任务失败") {
		return message
	}
	return "任务失败: " + message
}
