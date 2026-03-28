package updater

import (
	"fmt"
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
	return DeployModeDocker
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
		return ":18091"
	}
	return value
}

func UpdaterBaseURL() string {
	value := strings.TrimSpace(viper.GetString("update.updater.baseUrl"))
	if value == "" {
		return "http://updater:18091"
	}
	return strings.TrimRight(value, "/")
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

func HealthURLForMode(_ DeployMode) string {
	configured := strings.TrimSpace(viper.GetString("update.healthUrl"))
	if configured != "" {
		return configured
	}
	port := strings.TrimSpace(viper.GetString("server.port"))
	if port == "" {
		port = "18090"
	}
	return fmt.Sprintf("http://server:%s/api/v1/public/discovery", port)
}
