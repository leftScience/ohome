package conf

import (
	"fmt"
	"os"
	"strings"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

var initSQLTables = []string{
	"sys_config",
	"sys_dict_data",
	"sys_dict_type",
	"sys_file",
	"sys_quark_auto_save_task",
	"sys_quark_config",
	"sys_role",
	"sys_user",
	"sys_user_config",
	"user_media_history",
}

func importInitSQLIfNeeded(db *gorm.DB) error {
	if !viper.GetBool("DB.ImportInitSQLOnFirstRun") {
		return nil
	}

	initSQLPath := strings.TrimSpace(viper.GetString("DB.InitSQLPath"))
	if initSQLPath == "" {
		return nil
	}

	shouldImport, err := databaseLooksEmpty(db)
	if err != nil {
		return err
	}
	if !shouldImport {
		return nil
	}

	content, err := os.ReadFile(initSQLPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	statements := splitSQLStatements(string(content))
	if len(statements) == 0 {
		return nil
	}

	return db.Transaction(func(tx *gorm.DB) error {
		for _, stmt := range statements {
			stmt = strings.TrimSpace(normalizeMySQLDumpStatement(stmt))
			if stmt == "" {
				continue
			}
			if err := tx.Exec(stmt).Error; err != nil {
				return fmt.Errorf("执行初始化SQL失败: %w", err)
			}
		}
		return nil
	})
}

func databaseLooksEmpty(db *gorm.DB) (bool, error) {
	for _, tableName := range initSQLTables {
		var total int64
		if err := db.Table(tableName).Count(&total).Error; err != nil {
			return false, err
		}
		if total > 0 {
			return false, nil
		}
	}
	return true, nil
}

func splitSQLStatements(raw string) []string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}

	statements := make([]string, 0, 16)
	var builder strings.Builder
	inSingleQuote := false
	escaped := false

	for i := 0; i < len(raw); i++ {
		ch := raw[i]

		switch ch {
		case '\'':
			builder.WriteByte(ch)
			if inSingleQuote {
				if escaped {
					escaped = false
					continue
				}
				if i+1 < len(raw) && raw[i+1] == '\'' {
					builder.WriteByte(raw[i+1])
					i++
					continue
				}
				inSingleQuote = false
				continue
			}
			inSingleQuote = true
		case '\\':
			builder.WriteByte(ch)
			if inSingleQuote {
				escaped = !escaped
				continue
			}
		case ';':
			if inSingleQuote {
				builder.WriteByte(ch)
				escaped = false
				continue
			}
			statement := strings.TrimSpace(builder.String())
			if statement != "" {
				statements = append(statements, statement)
			}
			builder.Reset()
			escaped = false
			continue
		default:
			builder.WriteByte(ch)
		}

		if ch != '\\' {
			escaped = false
		}
	}

	if statement := strings.TrimSpace(builder.String()); statement != "" {
		statements = append(statements, statement)
	}

	return statements
}

func normalizeMySQLDumpStatement(stmt string) string {
	if strings.TrimSpace(stmt) == "" {
		return stmt
	}

	var builder strings.Builder
	inSingleQuote := false

	for i := 0; i < len(stmt); i++ {
		ch := stmt[i]

		if !inSingleQuote {
			builder.WriteByte(ch)
			if ch == '\'' {
				inSingleQuote = true
			}
			continue
		}

		switch ch {
		case '\\':
			if i+1 >= len(stmt) {
				builder.WriteByte(ch)
				continue
			}
			i++
			switch stmt[i] {
			case '0':
				builder.WriteByte(0)
			case 'b':
				builder.WriteByte('\b')
			case 'n':
				builder.WriteByte('\n')
			case 'r':
				builder.WriteByte('\r')
			case 't':
				builder.WriteByte('\t')
			case 'Z':
				builder.WriteByte(26)
			case '\\':
				builder.WriteByte('\\')
			case '"':
				builder.WriteByte('"')
			case '\'':
				builder.WriteString("''")
			default:
				builder.WriteByte(stmt[i])
			}
		case '\'':
			builder.WriteByte(ch)
			if i+1 < len(stmt) && stmt[i+1] == '\'' {
				builder.WriteByte(stmt[i+1])
				i++
				continue
			}
			inSingleQuote = false
		default:
			builder.WriteByte(ch)
		}
	}

	return builder.String()
}
