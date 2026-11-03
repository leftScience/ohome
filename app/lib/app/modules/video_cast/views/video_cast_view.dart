import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../services/video_cast_service.dart';
import '../../../theme/app_theme.dart';

class VideoCastView extends StatefulWidget {
  const VideoCastView({
    super.key,
    this.url,
    this.title,
    this.sourcePath,
    this.asBottomSheet = false,
    this.onCastStarted,
  });

  final String? url;
  final String? title;
  final String? sourcePath;
  final bool asBottomSheet;
  final Future<void> Function()? onCastStarted;

  @override
  State<VideoCastView> createState() => _VideoCastViewState();
}

class _VideoCastViewState extends State<VideoCastView> {
  static const _networkChannel = MethodChannel('ohome/network_info');
  static const _searchTimeout = Duration(seconds: 20);

  final DLNAManager _searcher = DLNAManager();
  final Map<String, DLNADevice> _deviceList = <String, DLNADevice>{};
  final VideoCastService _castService = Get.find<VideoCastService>();

  late final String _url;
  late final String _title;
  late final String _sourcePath;

  Timer? _timer;
  bool _isSearching = false;
  bool _searchStopped = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final map = args is Map ? args.cast<dynamic, dynamic>() : const {};
    _url = (widget.url ?? map['url'] as String? ?? '').trim();
    _title = (widget.title ?? map['title'] as String? ?? '').trim();
    _sourcePath = (widget.sourcePath ?? map['path'] as String? ?? '').trim();
    if (_url.isNotEmpty) {
      unawaited(_onSearch(isInitial: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searcher.stop();
    unawaited(_setMulticastLock(enabled: false));
    super.dispose();
  }

  Future<void> _onSearch({bool isInitial = false}) async {
    if (_isSearching || _url.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchStopped = false;
      if (!isInitial) {
        _deviceList.clear();
      }
    });

    await _setMulticastLock(enabled: true);

    try {
      final deviceManager = await _searcher.start();
      _timer?.cancel();
      _timer = Timer(_searchTimeout, _stopSearch);
      await for (final deviceList in deviceManager.devices.stream) {
        if (!mounted) break;
        setState(() {
          _deviceList.addAll(deviceList);
        });
      }
    } catch (error) {
      if (mounted) {
        Get.snackbar('投屏搜索失败', error.toString());
      }
    } finally {
      await _setMulticastLock(enabled: false);
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _stopSearch() {
    _timer?.cancel();
    _timer = null;
    _searchStopped = true;
    _searcher.stop();
  }

  Future<void> _castToDevice(String key, DLNADevice device) async {
    if (_url.isEmpty) return;
    final success = await _castService.startCasting(
      deviceKey: key,
      device: device,
      url: _url,
      title: _effectiveTitle,
      sourcePath: _sourcePath,
    );
    if (!mounted) return;
    if (success) {
      await widget.onCastStarted?.call();
      Get.snackbar('投屏已开始', device.info.friendlyName);
      Get.back(result: true);
      return;
    }
    Get.snackbar('投屏失败', '设备没有接受当前视频');
  }

  Future<void> _setMulticastLock({required bool enabled}) async {
    try {
      await _networkChannel.invokeMethod<void>(
        enabled ? 'acquireMulticastLock' : 'releaseMulticastLock',
      );
    } on PlatformException {
      return;
    }
  }

  String get _effectiveTitle {
    if (_title.isNotEmpty) return _title;
    return '当前视频';
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: !widget.asBottomSheet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.asBottomSheet ? 10 : 12,
              16,
              0,
            ),
            child: Row(
              children: [
                if (widget.asBottomSheet)
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppThemeColors.borderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Text(
                      '投屏',
                      style: TextStyle(
                        color: AppThemeColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: '重新搜索',
                  onPressed: _url.isEmpty ? null : _onSearch,
                  icon: const Icon(
                    Icons.refresh,
                    color: AppThemeColors.textPrimary,
                  ),
                ),
                if (widget.asBottomSheet)
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.close,
                      color: AppThemeColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppThemeColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppThemeColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _effectiveTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppThemeColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _url.isEmpty ? '当前视频没有可投屏地址' : '请选择同一局域网中的 DLNA 设备',
                  style: const TextStyle(
                    color: AppThemeColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody()),
        ],
      ),
    );

    if (widget.asBottomSheet) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.76,
              decoration: BoxDecoration(
                color: AppThemeColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                border: Border.all(color: AppThemeColors.border),
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppThemeColors.pageBackground,
        title: const Text('投屏'),
        actions: [
          IconButton(
            tooltip: '重新搜索',
            onPressed: _url.isEmpty ? null : _onSearch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildBody() {
    if (_url.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '当前视频没有可投屏地址',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppThemeColors.textSecondary),
          ),
        ),
      );
    }

    if (_deviceList.isEmpty) {
      final message = _isSearching
          ? '正在搜索设备...'
          : _searchStopped
          ? '没有发现可投屏设备'
          : '准备搜索投屏设备...';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cast_outlined,
                size: 48,
                color: AppThemeColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppThemeColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '确认手机和电视在同一局域网，并且电视已开启投屏/媒体渲染功能。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppThemeColors.textDisabled,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final keys = _deviceList.keys.toList(growable: false);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: keys.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final key = keys[index];
        final device = _deviceList[key]!;
        final selected = key == _castService.currentDeviceKey.value;
        return Material(
          color: selected
              ? AppThemeColors.primary.withValues(alpha: 0.12)
              : AppThemeColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => unawaited(_castToDevice(key, device)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.cast_connected : Icons.tv,
                    color: selected
                        ? AppThemeColors.primary
                        : AppThemeColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.info.friendlyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? AppThemeColors.primary
                                : AppThemeColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppThemeColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
