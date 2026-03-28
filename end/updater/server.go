package updater

import (
	"net/http"
	"strings"

	"ohome/utils"

	"github.com/gin-gonic/gin"
)

type APIServer struct {
	manager *Manager
}

func NewAPIServer() *APIServer {
	return &APIServer{manager: NewManager()}
}

func (s *APIServer) Run() error {
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		if !strings.HasPrefix(c.Request.URL.Path, "/internal/update") {
			c.Next()
			return
		}
		if c.GetHeader("X-Ohome-Updater-Token") != UpdaterToken() {
			utils.PermissionFail("updater token 无效", c)
			return
		}
		c.Next()
	})
	r.GET("/internal/update/info", s.handleInfo)
	r.POST("/internal/update/check", s.handleCheck)
	r.POST("/internal/update/apply", s.handleApply)
	r.GET("/internal/update/tasks/:taskId", s.handleTask)
	r.POST("/internal/update/rollback", s.handleRollback)
	return (&http.Server{Addr: UpdaterListenAddr(), Handler: r}).ListenAndServe()
}

func (s *APIServer) handleInfo(c *gin.Context) {
	result, err := s.manager.Info()
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func (s *APIServer) handleCheck(c *gin.Context) {
	var req CheckRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	result, err := s.manager.Check(req)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func (s *APIServer) handleApply(c *gin.Context) {
	var req ApplyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	result, err := s.manager.Apply(req)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func (s *APIServer) handleTask(c *gin.Context) {
	taskID := c.Param("taskId")
	result, err := s.manager.Task(taskID)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}

func (s *APIServer) handleRollback(c *gin.Context) {
	var req RollbackRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	result, err := s.manager.Rollback(req)
	if err != nil {
		utils.FailWithMessage(err.Error(), c)
		return
	}
	utils.OkWithData(result, c)
}
