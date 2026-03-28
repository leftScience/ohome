package updater

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"ohome/conf"

	"github.com/spf13/viper"
)

const (
	defaultManifestURL  = "https://github.com/leftScience/ohome/releases/latest/download/server-manifest.json"
	defaultUpdaterToken = "ohome-local-updater"
)

func DetectDeployMode() DeployMode {
	configured := strings.ToLower(strings.TrimSpace(viper.GetString("update.deployMode")))
	switch configured {
	case string(DeployModeDocker):
		return DeployModeDocker
	case string(DeployModePortable):
		return DeployModePortable
	}
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return DeployModeDocker
	}
	return DeployModePortable
}

func ManifestURL() string {
	value := strings.TrimSpace(viper.GetString("update.manifestUrl"))
	if value == "" {
		return defaultManifestURL
	}
	return value
}

func DefaultChannel() string {
	value := strings.TrimSpace(viper.GetString("update.channel"))
	if value == "" {
		return "stable"
	}
	return value
}

func UpdaterToken() string {
	value := strings.TrimSpace(viper.GetString("update.updater.token"))
	if value == "" {
		return defaultUpdaterToken
	}
	return value
}

func UpdaterListenAddr() string {
	value := strings.TrimSpace(viper.GetString("update.updater.listenAddr"))
	if value == "" {
		if DetectDeployMode() == DeployModeDocker {
			return ":18091"
		}
		return "127.0.0.1:18091"
	}
	return value
}

func UpdaterBaseURL() string {
	value := strings.TrimSpace(viper.GetString("update.updater.baseUrl"))
	if value == "" {
		if DetectDeployMode() == DeployModeDocker {
			return "http://updater:18091"
		}
		return "http://127.0.0.1:18091"
	}
	return strings.TrimRight(value, "/")
}

func PortableCurrentVersionFile() string {
	value := strings.TrimSpace(viper.GetString("update.portable.currentVersionFile"))
	if value == "" {
		return conf.ResolveAppPath("current.txt")
	}
	return conf.ResolveAppPath(value)
}

func PortableVersionsDir() string {
	value := strings.TrimSpace(viper.GetString("update.portable.versionsDir"))
	if value == "" {
		return conf.ResolveAppPath("versions")
	}
	return conf.ResolveAppPath(value)
}

func PortableServerPIDFile() string {
	value := strings.TrimSpace(viper.GetString("update.portable.serverPidFile"))
	if value == "" {
		return conf.ResolveAppPath(filepath.Join("data", "update", "server.pid"))
	}
	return conf.ResolveAppPath(value)
}

func PortableDownloadDir() string {
	value := strings.TrimSpace(viper.GetString("update.portable.downloadDir"))
	if value == "" {
		return conf.ResolveAppPath(filepath.Join("data", "update", "downloads"))
	}
	return conf.ResolveAppPath(value)
}

func DockerComposeProjectDir() string {
	value := strings.TrimSpace(viper.GetString("update.docker.composeProjectDir"))
	if value == "" {
		return conf.AppBaseDir()
	}
	return conf.ResolveAppPath(value)
}

func DockerComposeFile() string {
	value := strings.TrimSpace(viper.GetString("update.docker.composeFile"))
	if value == "" {
		return filepath.Join(DockerComposeProjectDir(), "docker-compose.release.yml")
	}
	if filepath.IsAbs(value) {
		return value
	}
	return filepath.Join(DockerComposeProjectDir(), value)
}

func DockerEnvFile() string {
	value := strings.TrimSpace(viper.GetString("update.docker.envFile"))
	if value == "" {
		return filepath.Join(DockerComposeProjectDir(), ".env")
	}
	if filepath.IsAbs(value) {
		return value
	}
	return filepath.Join(DockerComposeProjectDir(), value)
}

func DockerServiceName() string {
	value := strings.TrimSpace(viper.GetString("update.docker.serviceName"))
	if value == "" {
		return "server"
	}
	return value
}

func DockerImageEnvName() string {
	value := strings.TrimSpace(viper.GetString("update.docker.imageEnvName"))
	if value == "" {
		return "OHOME_SERVER_IMAGE"
	}
	return value
}

func HealthURLForMode(mode DeployMode) string {
	configured := strings.TrimSpace(viper.GetString("update.healthUrl"))
	if configured != "" {
		return configured
	}
	port := strings.TrimSpace(viper.GetString("server.port"))
	if port == "" {
		port = "18090"
	}
	host := "127.0.0.1"
	if mode == DeployModeDocker {
		host = "server"
	}
	return fmt.Sprintf("http://%s:%s/api/v1/public/discovery", host, port)
}
