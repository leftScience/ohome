package model

import "time"

const (
	QuarkTransferTaskStatusQueued     = "queued"
	QuarkTransferTaskStatusProcessing = "processing"
	QuarkTransferTaskStatusSuccess    = "success"
	QuarkTransferTaskStatusFailed     = "failed"
)

const (
	QuarkTransferTaskSourceSearchManual = "search_manual"
	QuarkTransferTaskSourceSyncManual   = "sync_manual"
	QuarkTransferTaskSourceSyncSchedule = "sync_schedule"
)

type QuarkTransferTask struct {
	CommonModel

	OwnerUserID   uint       `json:"ownerUserId" gorm:"not null;default:0;index"`
	DisplayName   string     `json:"displayName" gorm:"size:255;not null;default:''"`
	ShareURL      string     `json:"shareUrl" gorm:"size:1000;not null;default:''"`
	SavePath      string     `json:"savePath" gorm:"size:255;not null;default:''"`
	Passcode      string     `json:"passcode" gorm:"size:32;not null;default:''"`
	Application   string     `json:"application" gorm:"size:100;not null;default:''"`
	SourceType    string     `json:"sourceType" gorm:"size:50;not null;default:''"`
	SourceTaskID  *uint      `json:"sourceTaskId"`
	Status        string     `json:"status" gorm:"size:50;not null;default:'queued'"`
	ResultMessage string     `json:"resultMessage" gorm:"size:500;not null;default:''"`
	SavedCount    int        `json:"savedCount" gorm:"not null;default:0"`
	StartedAt     *time.Time `json:"startedAt"`
	FinishedAt    *time.Time `json:"finishedAt"`
}

func (QuarkTransferTask) TableName() string { return "sys_quark_transfer_task" }
