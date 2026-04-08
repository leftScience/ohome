package model

import (
	"strings"
	"time"
)

const (
	AppMessageSourceDrops  = "drops"
	AppMessageSourceQuark  = "quark"
	AppMessageSourceSystem = "system"
)

const (
	AppMessageTypeDropsItemExpire     = "drops_item_expire"
	AppMessageTypeDropsEventReminder  = "drops_event_reminder"
	AppMessageTypeQuarkTransferDone   = "quark_transfer_done"
	AppMessageTypeQuarkTransferFail   = "quark_transfer_fail"
	AppMessageTypeSystemBroadcast     = "system_broadcast"
)

const (
	AppMessageBizTypeQuarkTransferTask = "quark_transfer_task"
)

type AppMessage struct {
	CommonModel
	OwnerUserID uint       `json:"ownerUserId" gorm:"not null;default:0;index"`
	CreatedBy   uint       `json:"createdBy" gorm:"not null;default:0"`
	UpdatedBy   uint       `json:"updatedBy" gorm:"not null;default:0"`
	Source      string     `json:"source" gorm:"size:32;not null;index"`
	SourceKey   string     `json:"sourceKey" gorm:"size:191;not null;default:'';index"`
	MessageType string     `json:"messageType" gorm:"size:32;not null;index"`
	BizType     string     `json:"bizType" gorm:"size:20;not null;default:'';index"`
	BizID       uint       `json:"bizId" gorm:"not null;default:0;index"`
	UniqueKey   string     `json:"uniqueKey" gorm:"size:191;not null;uniqueIndex:uk_app_message_unique_key"`
	Title       string     `json:"title" gorm:"size:200;not null"`
	Summary     string     `json:"summary" gorm:"size:500"`
	TriggerDate time.Time  `json:"triggerDate" gorm:"not null;index"`
	Read        bool       `json:"read" gorm:"not null;default:false;index"`
	ReadAt      *time.Time `json:"readAt"`
}

func (AppMessage) TableName() string { return "app_message" }

func BuildAppMessageUniqueKey(source, sourceKey string) string {
	return strings.TrimSpace(strings.ToLower(source)) + ":" + strings.TrimSpace(sourceKey)
}
