package dto

// QuarkPathDTO 用于带路径的操作
type QuarkPathDTO struct {
	QuarkApplicationDTO
	Path     string `json:"path" form:"path"`
	Page     int    `json:"page,omitempty" form:"page"`
	Size     int    `json:"size,omitempty" form:"size"`
	SortType string `json:"sortType,omitempty" form:"sortType"`
}

// QuarkRenameDTO 用于重命名
type QuarkRenameDTO struct {
	QuarkApplicationDTO
	Path    string `json:"path" form:"path"`
	NewName string `json:"newName" form:"newName"`
}

// QuarkFsInfo 文件/文件夹信息
type QuarkFsInfo struct {
	Name      string `json:"name"`
	Path      string `json:"path"`
	StreamURL string `json:"streamUrl"`
	IsDir     bool   `json:"isDir"`
	Size      int64  `json:"size"`
	UpdatedAt int64  `json:"updatedAt"`
}

// QuarkFsMetaInfo 文件/目录元数据
type QuarkFsMetaInfo struct {
	ID           string         `json:"id"`
	Name         string         `json:"name"`
	Path         string         `json:"path"`
	IsDir        bool           `json:"isDir"`
	Size         int64          `json:"size"`
	UpdatedAt    int64          `json:"updatedAt"`
	CreatedAt    int64          `json:"createdAt"`
	Modified     string         `json:"modified"`
	Created      string         `json:"created"`
	Sign         string         `json:"sign"`
	Thumb        string         `json:"thumb"`
	Type         int            `json:"type"`
	HashInfoRaw  string         `json:"hashInfoRaw"`
	HashInfo     any            `json:"hashInfo"`
	MountDetails map[string]any `json:"mountDetails"`
}
