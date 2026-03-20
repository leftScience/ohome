# ohome

Flutter 客户端应用。

## 环境配置

环境文件：
- `assets/env/dev.json`
- `assets/env/prod.json`

运行时通过 `APP_ENV` 选择环境：
- 开发：`flutter run --dart-define=APP_ENV=dev`
- 生产：`flutter run --dart-define=APP_ENV=prod`
- 打包：`flutter build apk --dart-define=APP_ENV=prod`
- 一键打包：`bash build_prod.sh`
- 发布版本号以 `pubspec.yaml` 的 `version: x.y.z+n` 为准
- GitHub 发版 tag 支持 `v0.0.3` 和 `v0.0.3-build2` 两种格式
- 如果 `version: 0.0.3+2`，建议发布 `v0.0.3-build2`

运行在浏览器 
- 开发：`flutter run -d chrome`
