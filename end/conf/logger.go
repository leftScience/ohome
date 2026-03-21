package conf

import (
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/viper"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"gopkg.in/natefinch/lumberjack.v2"
)

func InitLogger() *zap.SugaredLogger {
	// Warn level and above only
	level := zapcore.WarnLevel

	core := zapcore.NewCore(getEncoder(), zapcore.NewMultiWriteSyncer(getWriteSync(), zapcore.AddSync(os.Stdout)), level)
	return zap.New(core).Sugar()
}

func getEncoder() zapcore.Encoder {
	encoderConfig := zap.NewProductionEncoderConfig()
	encoderConfig.TimeKey = "time"
	encoderConfig.EncodeLevel = zapcore.CapitalLevelEncoder
	encoderConfig.EncodeTime = func(t time.Time, encoder zapcore.PrimitiveArrayEncoder) {
		encoder.AppendString(t.Local().Format(time.DateTime))
	}
	return zapcore.NewJSONEncoder(encoderConfig)
}
func getWriteSync() zapcore.WriteSyncer {
	logPath := ResolveAppPath(filepath.Join("log", time.Now().Format(time.DateOnly)+".log"))
	_ = os.MkdirAll(filepath.Dir(logPath), 0o755)
	if file, err := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND, 0o644); err == nil {
		_ = file.Close()
	}

	lumberjackSyncer := &lumberjack.Logger{
		Filename:   logPath,
		MaxSize:    viper.GetInt("logger.MaxSize"),    // 日志切割的开始
		MaxBackups: viper.GetInt("logger.MaxBackups"), //保留的最大数量
		MaxAge:     viper.GetInt("logger.MaxAge"),     //保留的最长时间
		Compress:   false,                             // disabled by default
	}

	return zapcore.AddSync(lumberjackSyncer)
}
