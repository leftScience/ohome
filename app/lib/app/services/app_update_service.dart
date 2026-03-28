import 'dart:async';

import 'package:get/get.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/api/app_update.dart';
import '../data/models/app_update_info.dart';
import '../utils/app_env.dart';
import '../utils/http_client.dart';

enum AppUpdateCheckStatus {
  available,
  upToDate,
  notConfigured,
  unsupported,
  disabledInDev,
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.info,
  });

  final AppUpdateCheckStatus status;
  final String currentVersion;
  final AppUpdateInfo? info;
}

class AppUpdateService extends GetxService {
  AppUpdateService({AppUpdateApi? appUpdateApi})
    : _appUpdateApi = appUpdateApi ?? AppUpdateApi();

  final AppUpdateApi _appUpdateApi;
  PackageInfo? _packageInfo;

  final isUpdating = false.obs;
  final progress = RxnDouble();
  final statusText = ''.obs;

  Future<String> getCurrentVersionLabel() async {
    final packageInfo = await _getPackageInfo();
    return _buildCurrentVersionLabel(packageInfo);
  }

  Future<AppUpdateCheckResult> checkForUpdate() async {
    final packageInfo = await _getPackageInfo();
    final currentVersion = _buildCurrentVersionLabel(packageInfo);

    if (AppEnv.currentEnvironment == AppEnvironment.dev) {
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.disabledInDev,
        currentVersion: currentVersion,
      );
    }

    if (!GetPlatform.isAndroid) {
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.unsupported,
        currentVersion: currentVersion,
      );
    }

    final manifestUrl = AppEnv.instance.appUpdateManifestUrl;
    if (manifestUrl == null || manifestUrl.isEmpty) {
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.notConfigured,
        currentVersion: currentVersion,
      );
    }

    final latest = await _appUpdateApi.fetchManifest(manifestUrl: manifestUrl);
    final currentCode = int.tryParse(packageInfo.buildNumber.trim());
    final hasUpdate = _isNewerVersion(
      currentVersionName: packageInfo.version,
      currentVersionCode: currentCode,
      latest: latest,
    );

    return AppUpdateCheckResult(
      status: hasUpdate
          ? AppUpdateCheckStatus.available
          : AppUpdateCheckStatus.upToDate,
      currentVersion: currentVersion,
      info: hasUpdate ? latest : null,
    );
  }

  Future<void> startUpdate(AppUpdateInfo info) async {
    if (AppEnv.currentEnvironment == AppEnvironment.dev) {
      throw ApiException('开发环境已禁用在线更新');
    }
    if (!GetPlatform.isAndroid) {
      throw ApiException('当前平台不支持 APK 在线更新');
    }
    if (isUpdating.value) {
      throw ApiException('已有更新任务正在进行中');
    }

    isUpdating.value = true;
    progress.value = null;
    statusText.value = '准备下载更新...';

    final completer = Completer<void>();
    StreamSubscription<OtaEvent>? subscription;

    try {
      subscription = OtaUpdate()
          .execute(
            info.apkUrl,
            destinationFilename: info.buildDestinationFilename(),
            sha256checksum: info.sha256checksum,
            usePackageInstaller: AppEnv.instance.appUpdateUsePackageInstaller,
          )
          .listen(
            (event) => _handleOtaEvent(event, completer),
            onError: (error) {
              if (!completer.isCompleted) {
                completer.completeError(ApiException('更新失败：$error'));
              }
            },
            onDone: () {
              if (!completer.isCompleted) {
                completer.complete();
              }
            },
          );

      await completer.future.timeout(
        const Duration(minutes: 20),
        onTimeout: () => throw ApiException('更新超时，请稍后重试'),
      );
    } finally {
      await subscription?.cancel();
      isUpdating.value = false;
    }
  }

  Future<void> cancelUpdate() async {
    if (!isUpdating.value) return;
    await OtaUpdate().cancel();
    statusText.value = '已取消更新';
  }

  void _handleOtaEvent(OtaEvent event, Completer<void> completer) {
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final percent = _parsePercent(event.value);
        progress.value = percent;
        statusText.value = percent == null
            ? '正在下载更新包...'
            : '正在下载更新包 ${percent.toStringAsFixed(0)}%';
        break;
      case OtaStatus.INSTALLING:
        final installerPercent = _parsePercent(event.value);
        progress.value = installerPercent;
        statusText.value = installerPercent == null
            ? '下载完成，正在拉起安装...'
            : '正在安装 ${installerPercent.toStringAsFixed(0)}%';
        if (!completer.isCompleted &&
            !AppEnv.instance.appUpdateUsePackageInstaller) {
          completer.complete();
        }
        break;
      case OtaStatus.INSTALLATION_DONE:
        progress.value = 100;
        statusText.value = '安装完成';
        if (!completer.isCompleted) {
          completer.complete();
        }
        break;
      case OtaStatus.ALREADY_RUNNING_ERROR:
        _completeError(completer, '已有更新任务正在进行中');
        break;
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _completeError(completer, '安装权限被拒绝，请在系统设置中允许安装未知来源应用');
        break;
      case OtaStatus.DOWNLOAD_ERROR:
        _completeError(completer, event.value ?? '下载失败，请检查网络和下载地址');
        break;
      case OtaStatus.CHECKSUM_ERROR:
        _completeError(completer, '安装包校验失败，请重新下载');
        break;
      case OtaStatus.CANCELED:
        _completeError(completer, '已取消更新');
        break;
      case OtaStatus.INSTALLATION_ERROR:
        _completeError(completer, event.value ?? '安装失败');
        break;
      case OtaStatus.INTERNAL_ERROR:
        _completeError(completer, event.value ?? '更新失败，请稍后重试');
        break;
    }
  }

  void _completeError(Completer<void> completer, String message) {
    statusText.value = message;
    if (!completer.isCompleted) {
      completer.completeError(ApiException(message));
    }
  }

  bool _isNewerVersion({
    required String currentVersionName,
    required int? currentVersionCode,
    required AppUpdateInfo latest,
  }) {
    final latestCode = latest.versionCode;
    if (latestCode != null && currentVersionCode != null) {
      if (latestCode != currentVersionCode) {
        return latestCode > currentVersionCode;
      }
    }

    final versionDiff = _compareVersionName(
      latest.versionName,
      currentVersionName,
    );
    if (versionDiff != 0) return versionDiff > 0;

    if (latestCode == null || currentVersionCode == null) return false;
    return latestCode > currentVersionCode;
  }

  int _compareVersionName(String a, String b) {
    final left = _versionParts(a);
    final right = _versionParts(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final lv = i < left.length ? left[i] : 0;
      final rv = i < right.length ? right[i] : 0;
      if (lv == rv) continue;
      return lv > rv ? 1 : -1;
    }
    return 0;
  }

  List<int> _versionParts(String value) {
    final matches = RegExp(r'\d+').allMatches(value);
    if (matches.isEmpty) return const [];
    return matches
        .map((match) => int.tryParse(match.group(0) ?? '') ?? 0)
        .toList(growable: false);
  }

  double? _parsePercent(String? value) {
    if (value == null) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return null;
    if (parsed < 0) return 0;
    if (parsed > 100) return 100;
    return parsed;
  }

  String _buildCurrentVersionLabel(PackageInfo packageInfo) {
    final version = packageInfo.version.trim();
    final build = packageInfo.buildNumber.trim();
    if (build.isEmpty) return version;
    if (version.isEmpty) return build;
    return '$version+$build';
  }

  Future<PackageInfo> _getPackageInfo() async {
    return _packageInfo ??= await PackageInfo.fromPlatform();
  }
}
