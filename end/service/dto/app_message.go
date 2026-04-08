package dto

type AppMessageListDTO struct {
	Source   string `json:"source" form:"source"`
	ReadOnly *bool  `json:"readOnly" form:"readOnly"`
	Paginate
}

type AppMessageReadDTO struct {
	ID uint `json:"id" form:"id"`
}

type SendSystemMessageDTO struct {
	Title   string `json:"title" form:"title" binding:"required"`
	Content string `json:"content" form:"content" binding:"required"`
}
