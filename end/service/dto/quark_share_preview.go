package dto

type QuarkSharePreviewDTO struct {
	ShareURL string `json:"shareUrl" form:"shareUrl"`
	Passcode string `json:"passcode" form:"passcode"`
	PdirFid  string `json:"pdirFid" form:"pdirFid"`
}

type QuarkSharePreviewFileDTO struct {
	Fid       string `json:"fid"`
	FileName  string `json:"fileName"`
	IsDir     bool   `json:"isDir"`
	Size      int64  `json:"size"`
	UpdatedAt int64  `json:"updatedAt"`
}

type QuarkSharePreviewResultDTO struct {
	Files   []QuarkSharePreviewFileDTO `json:"files"`
	PdirFid string                     `json:"pdirFid"`
}