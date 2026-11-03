package dto

type QuarkTransferTaskListDTO struct {
	Keyword    string `json:"keyword" form:"keyword"`
	Status     string `json:"status" form:"status"`
	SourceType string `json:"sourceType" form:"sourceType"`
	Paginate
}
