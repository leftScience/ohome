package updater

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"ohome/conf"
)

type Store struct {
	rootDir string
	mu      sync.Mutex
}

func NewStore() *Store {
	return &Store{rootDir: conf.ResolveAppPath(filepath.Join("data", "update"))}
}

func (s *Store) RootDir() string { return s.rootDir }

func (s *Store) TasksDir() string { return filepath.Join(s.rootDir, "tasks") }

func (s *Store) StatePath() string { return filepath.Join(s.rootDir, "state.json") }

func (s *Store) RuntimeRootDir() string { return filepath.Join(s.rootDir, "runtime") }

func (s *Store) ReleasesDir() string { return filepath.Join(s.RuntimeRootDir(), "releases") }

func (s *Store) TempDir() string { return filepath.Join(s.RuntimeRootDir(), "tmp") }

func (s *Store) CurrentReleaseLink() string { return filepath.Join(s.RuntimeRootDir(), "current") }

func (s *Store) ensure() error {
	if err := os.MkdirAll(s.TasksDir(), 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(s.ReleasesDir(), 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(s.TempDir(), 0o755); err != nil {
		return err
	}
	return nil
}

func (s *Store) SaveTask(task *Task) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.ensure(); err != nil {
		return err
	}
	path := filepath.Join(s.TasksDir(), task.ID+".json")
	return writeJSONAtomic(path, task)
}

func (s *Store) LoadTask(taskID string) (*Task, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if strings.TrimSpace(taskID) == "" {
		return nil, os.ErrNotExist
	}
	var task Task
	if err := readJSON(filepath.Join(s.TasksDir(), taskID+".json"), &task); err != nil {
		return nil, err
	}
	return &task, nil
}

func (s *Store) SaveState(state *State) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.ensure(); err != nil {
		return err
	}
	state.UpdatedAt = time.Now()
	return writeJSONAtomic(s.StatePath(), state)
}

func (s *Store) LoadState() (*State, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	state := &State{}
	if err := readJSON(s.StatePath(), state); err != nil {
		if os.IsNotExist(err) {
			return &State{}, nil
		}
		return nil, err
	}
	return state, nil
}

func (s *Store) LatestTask() (*Task, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.ensure(); err != nil {
		return nil, err
	}
	entries, err := os.ReadDir(s.TasksDir())
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	type fileTask struct {
		path string
		info os.FileInfo
	}
	items := make([]fileTask, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		items = append(items, fileTask{path: filepath.Join(s.TasksDir(), entry.Name()), info: info})
	}
	if len(items) == 0 {
		return nil, nil
	}
	sort.Slice(items, func(i, j int) bool {
		return items[i].info.ModTime().After(items[j].info.ModTime())
	})
	var task Task
	if err := readJSON(items[0].path, &task); err != nil {
		return nil, err
	}
	return &task, nil
}

func writeJSONAtomic(path string, value any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	payload, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, payload, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func readJSON(path string, value any) error {
	payload, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if len(payload) == 0 {
		return fmt.Errorf("JSON 内容为空：%s", path)
	}
	return json.Unmarshal(payload, value)
}
