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
