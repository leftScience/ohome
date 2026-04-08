package conf

import (
	"testing"

	puresqlite "github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/schema"

	"ohome/model"
)

func TestMigrateQuarkApplications(t *testing.T) {
	db := openQuarkMigrationTestDB(t)
	nowMusic := model.QuarkConfig{
		Application: quarkMusicApplication,
		RootPath:    "WP/MUSIC",
		Remark:      "音乐",
	}
	oldNovel := model.QuarkConfig{
		Application: quarkNovelApplication,
		RootPath:    "WP/XS",
		Remark:      "有声书",
	}
	if err := db.Create(&nowMusic).Error; err != nil {
		t.Fatalf("seed music failed: %v", err)
	}
	if err := db.Create(&oldNovel).Error; err != nil {
		t.Fatalf("seed xiaoshuo failed: %v", err)
	}

	if err := migrateQuarkApplications(db); err != nil {
		t.Fatalf("migrate failed: %v", err)
	}
	if err := migrateQuarkApplications(db); err != nil {
		t.Fatalf("migrate should be idempotent: %v", err)
	}

	var configs []model.QuarkConfig
	if err := db.Order("application asc").Find(&configs).Error; err != nil {
		t.Fatalf("query configs failed: %v", err)
	}

	if len(configs) != 2 {
		t.Fatalf("config count = %d, want 2", len(configs))
	}

	music := findQuarkConfig(configs, quarkMusicApplication)
	if music == nil {
		t.Fatal("music config missing")
	}
	if music.Remark != quarkMusicRemark {
		t.Fatalf("music remark = %q, want %q", music.Remark, quarkMusicRemark)
	}

	read := findQuarkConfig(configs, quarkReadApplication)
	if read == nil {
		t.Fatal("read config missing")
	}
	if read.RootPath != quarkReadRootPath {
		t.Fatalf("read root_path = %q, want %q", read.RootPath, quarkReadRootPath)
	}
	if read.Remark != quarkReadRemark {
		t.Fatalf("read remark = %q, want %q", read.Remark, quarkReadRemark)
	}
}

func openQuarkMigrationTestDB(t *testing.T) *gorm.DB {
	t.Helper()

	db, err := gorm.Open(puresqlite.Open(":memory:"), &gorm.Config{
		NamingStrategy: schema.NamingStrategy{
			TablePrefix:   "sys_",
			SingularTable: true,
		},
	})
	if err != nil {
		t.Fatalf("open sqlite failed: %v", err)
	}
	if err := db.AutoMigrate(&model.QuarkConfig{}); err != nil {
		t.Fatalf("migrate schema failed: %v", err)
	}
	return db
}

func findQuarkConfig(configs []model.QuarkConfig, application string) *model.QuarkConfig {
	for i := range configs {
		if configs[i].Application == application {
			return &configs[i]
		}
	}
	return nil
}
