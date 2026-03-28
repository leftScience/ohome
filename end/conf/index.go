package conf

import (
	"fmt"
	"strings"

	"github.com/spf13/viper"
)

func InitConfig() {
	viper.SetDefault("DB.driver", "sqlite")
	viper.SetDefault("DB.dsn", "./data/ohome.db")
	viper.SetDefault("DB.MaxIdleConns", 10)
	viper.SetDefault("DB.MaxOpenConns", 100)
	viper.SetDefault("DB.AutoMigrate", true)
	viper.SetDefault("DB.InitData", true)
	viper.SetDefault("DB.InitSQLPath", "./sql/init_data.sql")
	viper.SetDefault("DB.ImportInitSQLOnFirstRun", true)
	viper.SetDefault("drops.itemReminderDays", "7,3,1,0")
	viper.SetDefault("drops.eventReminderDays", "7,3,1,0")
	viper.SetDefault("config.allowUserRegistration", true)
	viper.SetDefault("quark.stream.concurrency", 3)
	viper.SetDefault("quark.stream.partSizeMB", 10)
	viper.SetDefault("quark.stream.chunkMaxRetries", 3)
	viper.SetDefault("update.channel", "stable")
	viper.SetDefault("update.manifestUrl", "https://github.com/leftScience/ohome/releases/latest/download/server-manifest.json")
	viper.SetDefault("update.deployMode", "auto")
	viper.SetDefault("update.updater.token", "ohome-local-updater")
	viper.SetDefault("update.updater.listenAddr", "127.0.0.1:18091")
	viper.SetDefault("update.updater.baseUrl", "http://127.0.0.1:18091")
	viper.SetDefault("update.portable.currentVersionFile", "current.txt")
	viper.SetDefault("update.portable.versionsDir", "versions")
	viper.SetDefault("update.portable.serverPidFile", "./data/update/server.pid")
	viper.SetDefault("update.portable.downloadDir", "./data/update/downloads")
	viper.SetDefault("update.docker.composeProjectDir", ".")
	viper.SetDefault("update.docker.composeFile", "docker-compose.release.yml")
	viper.SetDefault("update.docker.envFile", ".env")
	viper.SetDefault("update.docker.serviceName", "server")
	viper.SetDefault("update.docker.imageEnvName", "OHOME_SERVER_IMAGE")
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viper.AutomaticEnv()

	configPath, err := configuredConfigPath()
	if err != nil {
		panic(fmt.Sprintf("读取配置文件异常,错误信息是 ：%v", err.Error()))
	}

	viper.SetConfigFile(configPath)
	if err := viper.ReadInConfig(); err != nil {
		panic(fmt.Sprintf("读取配置文件异常,错误信息是 ：%v", err.Error()))
	}

	normalizeRuntimeConfigPaths()
}
