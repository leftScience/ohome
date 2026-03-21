package conf

import (
	"os"
	"path/filepath"
)

func ensureTestFile(path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte("test"), 0o644)
}
