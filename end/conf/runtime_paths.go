package conf

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/viper"
)

const BaseDirEnv = "OHOME_BASE_DIR"

var appBaseDir string

func AppBaseDir() string {
	if strings.TrimSpace(appBaseDir) != "" {
		return appBaseDir
	}

	baseDir, _, err := locateConfigFile(os.Getenv(BaseDirEnv), executablePath, os.Getwd)
	if err == nil {
		appBaseDir = baseDir
		return appBaseDir
	}

	if wd, wdErr := os.Getwd(); wdErr == nil {
		appBaseDir = wd
		return appBaseDir
	}

	appBaseDir = "."
	return appBaseDir
}

func ResolveAppPath(path string) string {
	trimmed := strings.TrimSpace(path)
	if trimmed == "" {
		return ""
	}
	if filepath.IsAbs(trimmed) {
		return filepath.Clean(trimmed)
	}
	return filepath.Clean(filepath.Join(AppBaseDir(), trimmed))
}

func configuredConfigPath() (string, error) {
	baseDir, configPath, err := locateConfigFile(os.Getenv(BaseDirEnv), executablePath, os.Getwd)
	if err != nil {
		return "", err
	}
	appBaseDir = baseDir
	return configPath, nil
}

func normalizeRuntimeConfigPaths() {
	driver := detectDBDriver()
	if driver == "sqlite" {
		viper.Set("DB.dsn", resolveSQLiteDSN(AppBaseDir(), viper.GetString("DB.dsn")))
	}

	initSQLPath := strings.TrimSpace(viper.GetString("DB.InitSQLPath"))
	if initSQLPath != "" {
		viper.Set("DB.InitSQLPath", ResolveAppPath(initSQLPath))
	}
}

func locateConfigFile(envBaseDir string, execPathFn func() (string, error), getwdFn func() (string, error)) (string, string, error) {
	envBaseDir = strings.TrimSpace(envBaseDir)
	if envBaseDir != "" {
		baseDir, err := filepath.Abs(envBaseDir)
		if err != nil {
			return "", "", err
		}
		configPath := filepath.Join(baseDir, "conf", "config.yaml")
		if fileExists(configPath) {
			return baseDir, configPath, nil
		}
		return "", "", fmt.Errorf("未找到配置文件：%s", configPath)
	}

	exePath, exeErr := execPathFn()
	if exeErr == nil {
		exeDir := filepath.Dir(exePath)
		configPath := filepath.Join(exeDir, "conf", "config.yaml")
		if fileExists(configPath) {
			return exeDir, configPath, nil
		}
	}

	wd, wdErr := getwdFn()
	if wdErr == nil {
		configPath := filepath.Join(wd, "conf", "config.yaml")
		if fileExists(configPath) {
			return wd, configPath, nil
		}
	}

	return "", "", fmt.Errorf("在可执行文件目录和当前工作目录中均未找到配置文件")
}

func executablePath() (string, error) {
	return os.Executable()
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func resolveSQLiteDSN(baseDir string, dsn string) string {
	trimmed := strings.TrimSpace(dsn)
	if trimmed == "" {
		return filepath.Clean(filepath.Join(baseDir, "data", "ohome.db"))
	}

	lowerDSN := strings.ToLower(trimmed)
	if trimmed == ":memory:" || strings.Contains(lowerDSN, "mode=memory") {
		return trimmed
	}

	if strings.HasPrefix(lowerDSN, "file:") {
		pathAndQuery := trimmed[len("file:"):]
		parts := strings.SplitN(pathAndQuery, "?", 2)
		filePath := strings.TrimSpace(parts[0])
		if filePath == "" || filepath.IsAbs(filePath) {
			return trimmed
		}

		resolved := filepath.ToSlash(filepath.Clean(filepath.Join(baseDir, filePath)))
		if len(parts) == 2 {
			return "file:" + resolved + "?" + parts[1]
		}
		return "file:" + resolved
	}

	if filepath.IsAbs(trimmed) {
		return filepath.Clean(trimmed)
	}

	return filepath.Clean(filepath.Join(baseDir, trimmed))
}
