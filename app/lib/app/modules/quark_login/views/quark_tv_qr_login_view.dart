import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/api/quark_tv_login.dart';
import '../../../data/models/quark_tv_login_poll_response.dart';
import '../../../theme/app_theme.dart';

class QuarkTvQrLoginView extends StatefulWidget {
  const QuarkTvQrLoginView({
    super.key,
    required this.api,
    required this.initialQrData,
    this.credentialTarget,
  });

  final QuarkTvLoginApi api;
  final String initialQrData;
  final String? credentialTarget;

  @override
  State<QuarkTvQrLoginView> createState() => _QuarkTvQrLoginViewState();
}

class _QuarkTvQrLoginViewState extends State<QuarkTvQrLoginView> {
  Timer? _pollTimer;

  late String _qrData;
  String _statusText = '请使用夸克 TV 扫码确认登录';
  bool _loading = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _qrData = widget.initialQrData;
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollLogin(),
    );
    unawaited(_pollLogin());
  }

  Future<void> _pollLogin() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final result = await widget.api.pollLogin(
        credentialTarget: widget.credentialTarget,
        showErrorToast: false,
      );
      if (!mounted) return;
      _handlePollResult(result);
    } catch (error) {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() {
        _statusText = error.toString().trim().isEmpty
            ? '轮询登录状态失败'
            : error.toString().trim();
      });
    } finally {
      _polling = false;
    }
  }

  void _handlePollResult(QuarkTvLoginPollResponse result) {
    if (result.isSuccess) {
      _pollTimer?.cancel();
      Get.back<bool>(result: true);
      return;
    }

    setState(() {
      _statusText = result.message.isNotEmpty
          ? result.message
          : switch (result.status) {
              'pending' => '请在夸克 TV 上完成扫码确认',
              'expired' => '二维码已过期，请刷新后重试',
              'error' => '扫码登录失败，请稍后重试',
              _ => '等待扫码确认',
            };
    });

    if (!result.isPending) {
      _pollTimer?.cancel();
    }
  }

  Future<void> _refreshQrCode() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _statusText = '正在获取新的二维码...';
    });
    try {
      final result = await widget.api.startLogin(
        credentialTarget: widget.credentialTarget,
      );
      if (!mounted) return;
      setState(() {
        _qrData = result.qrData;
        _statusText = '请使用夸克 TV 扫码确认登录';
      });
      _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusText = error.toString().trim().isEmpty
            ? '获取二维码失败'
            : error.toString().trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Uint8List? _decodeQrBytes(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final commaIndex = trimmed.indexOf(',');
    final payload = trimmed.startsWith('data:image') && commaIndex >= 0
        ? trimmed.substring(commaIndex + 1)
        : trimmed;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrBytes = _decodeQrBytes(_qrData);
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: const Text('夸克TV扫码登录')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
        children: [
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: AppThemeColors.surface,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: AppThemeColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 240.w,
                  height: 240.w,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: AppThemeColors.border),
                  ),
                  child: qrBytes == null
                      ? Center(
                          child: Text(
                            '二维码加载失败',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppThemeColors.textMuted,
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.memory(
                            qrBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                ),
                SizedBox(height: 18.h),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppThemeColors.textSecondary,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  '扫码成功后会自动关闭此页面',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppThemeColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: FilledButton.icon(
          onPressed: _loading ? null : _refreshQrCode,
          style: FilledButton.styleFrom(
            minimumSize: Size(double.infinity, 50.h),
            backgroundColor: AppThemeColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          icon: _loading
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(_loading ? '获取中' : '刷新二维码'),
        ),
      ),
    );
  }
}
