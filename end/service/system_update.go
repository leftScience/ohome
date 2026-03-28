package service

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"ohome/buildinfo"
	"ohome/updater"
)

type SystemUpdateService struct{}

func (s *SystemUpdateService) Info() (updater.InfoResponse, error) {
	var result updater.InfoResponse
	err := s.request(http.MethodGet, "/internal/update/info", nil, &result)
	if err != nil {
		return updater.InfoResponse{
			DeployMode:       updater.DetectDeployMode(),
			CurrentVersion:   buildinfo.CleanVersion(),
			UpdaterReachable: false,
		}, nil
	}
	return result, nil
}

func (s *SystemUpdateService) Check(req updater.CheckRequest) (updater.CheckResponse, error) {
	var result updater.CheckResponse
	err := s.request(http.MethodPost, "/internal/update/check", req, &result)
	return result, err
}

func (s *SystemUpdateService) Apply(req updater.ApplyRequest) (updater.ApplyResponse, error) {
	var result updater.ApplyResponse
	err := s.request(http.MethodPost, "/internal/update/apply", req, &result)
	return result, err
}

func (s *SystemUpdateService) Task(taskID string) (*updater.Task, error) {
	var result updater.Task
	err := s.request(http.MethodGet, "/internal/update/tasks/"+strings.TrimSpace(taskID), nil, &result)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (s *SystemUpdateService) Rollback(req updater.RollbackRequest) (updater.ApplyResponse, error) {
	var result updater.ApplyResponse
	err := s.request(http.MethodPost, "/internal/update/rollback", req, &result)
	return result, err
}

func (s *SystemUpdateService) request(method string, path string, payload any, out any) error {
	var body io.Reader
	if payload != nil {
		encoded, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		body = bytes.NewReader(encoded)
	}
	req, err := http.NewRequest(method, updater.UpdaterBaseURL()+path, body)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Ohome-Updater-Token", updater.UpdaterToken())
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("连接 updater 失败: %w", err)
	}
	defer resp.Body.Close()
	var envelope struct {
		Code int             `json:"code"`
		Data json.RawMessage `json:"data"`
		Msg  string          `json:"msg"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&envelope); err != nil {
		return err
	}
	if envelope.Code != 200 {
		if strings.TrimSpace(envelope.Msg) == "" {
			return fmt.Errorf("updater 请求失败")
		}
		return errors.New(envelope.Msg)
	}
	if out == nil {
		return nil
	}
	return json.Unmarshal(envelope.Data, out)
}
