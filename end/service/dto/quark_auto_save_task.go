package dto

import "ohome/model"

type QuarkAutoSaveTaskListDTO struct {
	TaskName string `json:"taskName"`
	Enabled  *bool  `json:"enabled"`
	Paginate
}

type QuarkAutoSaveTaskUpdateDTO struct {
	ID uint `json:"id" form:"id"`

	TaskName string `json:"taskName" form:"taskName"`
	ShareURL string `json:"shareUrl" form:"shareUrl"`
	SavePath string `json:"savePath" form:"savePath"`

	ScheduleType string `json:"scheduleType" form:"scheduleType"`
	RunTime      string `json:"runTime" form:"runTime"`
	RunWeek      string `json:"runWeek" form:"runWeek"`

	Enabled bool `json:"enabled" form:"enabled"`
}

func (d *QuarkAutoSaveTaskUpdateDTO) ConvertToModel(m *model.QuarkAutoSaveTask) {
	m.ID = d.ID
	m.TaskName = d.TaskName
	m.ShareURL = d.ShareURL
	m.SavePath = d.SavePath
	m.ScheduleType = d.ScheduleType
	m.RunTime = d.RunTime
	m.RunWeek = d.RunWeek
	m.Enabled = d.Enabled
}

type QuarkAutoSaveTransferDTO struct {
	ShareURL     string `json:"shareUrl" form:"shareUrl"`
	SavePath     string `json:"savePath" form:"savePath"`
	Passcode     string `json:"passcode" form:"passcode"`
	Application  string `json:"application" form:"application"`
	ResourceName string `json:"resourceName" form:"resourceName"`
}
