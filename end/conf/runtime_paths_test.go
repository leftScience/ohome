package conf

import (
	"path/filepath"
	"testing"
)

func TestLocateConfigFilePrefersEnvBaseDir(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "conf", "config.yaml")
	if err := ensureTestFile(configPath); err != nil {
		t.Fatalf("ensure config file: %v", err)
	}

	baseDir, resolvedConfigPath, err := locateConfigFile(tempDir, func() (string, error) {
		t.Fatal("unexpected executable lookup")
		return "", nil
	}, func() (string, error) {
		t.Fatal("unexpected cwd lookup")
		return "", nil
	})
	if err != nil {
		t.Fatalf("locateConfigFile returned error: %v", err)
	}

	if baseDir != tempDir {
		t.Fatalf("baseDir = %q, want %q", baseDir, tempDir)
	}
	if resolvedConfigPath != configPath {
		t.Fatalf("configPath = %q, want %q", resolvedConfigPath, configPath)
	}
}

func TestLocateConfigFileFallsBackToCurrentWorkingDirectory(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "conf", "config.yaml")
	if err := ensureTestFile(configPath); err != nil {
		t.Fatalf("ensure config file: %v", err)
	}

	baseDir, resolvedConfigPath, err := locateConfigFile("", func() (string, error) {
		return filepath.Join(t.TempDir(), "ohome"), nil
	}, func() (string, error) {
		return tempDir, nil
	})
	if err != nil {
		t.Fatalf("locateConfigFile returned error: %v", err)
	}

	if baseDir != tempDir {
		t.Fatalf("baseDir = %q, want %q", baseDir, tempDir)
	}
	if resolvedConfigPath != configPath {
		t.Fatalf("configPath = %q, want %q", resolvedConfigPath, configPath)
	}
}

func TestResolveSQLiteDSN(t *testing.T) {
	baseDir := filepath.Join(string(filepath.Separator), "tmp", "ohome")

	testCases := []struct {
		name string
		dsn  string
		want string
	}{
		{
			name: "default relative file",
			dsn:  "",
			want: filepath.Join(baseDir, "data", "ohome.db"),
		},
		{
			name: "relative path",
			dsn:  "./data/app.db",
			want: filepath.Join(baseDir, "data", "app.db"),
		},
		{
			name: "file uri with relative path",
			dsn:  "file:./data/app.db?cache=shared",
			want: "file:/tmp/ohome/data/app.db?cache=shared",
		},
		{
			name: "memory dsn",
			dsn:  ":memory:",
			want: ":memory:",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			got := resolveSQLiteDSN(baseDir, tc.dsn)
			if got != tc.want {
				t.Fatalf("resolveSQLiteDSN(%q) = %q, want %q", tc.dsn, got, tc.want)
			}
		})
	}
}
