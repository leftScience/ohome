import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../theme/app_theme.dart';

/// 自定义网盘搜索源对应的网页搜索容器。
class PanWebSearchBody extends StatefulWidget {
  const PanWebSearchBody({super.key, required this.url});

  final String url;

  @override
  State<PanWebSearchBody> createState() => _PanWebSearchBodyState();
}

class _PanWebSearchBodyState extends State<PanWebSearchBody> {
  static final RegExp _quarkSharePattern = RegExp(
    r'https?://pan\.quark\.cn/s/[0-9A-Za-z]+',
  );

  InAppWebViewController? _webViewController;
  double _progress = 0;

  @override
  void didUpdateWidget(covariant PanWebSearchBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && widget.url.trim().isNotEmpty) {
      unawaited(_loadUrl(widget.url.trim()));
    }
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  Future<void> _loadUrl(String url) async {
    final controller = _webViewController;
    if (controller == null) return;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _openSharePreview(String shareUrl) {
    Get.toNamed(
      Routes.SHARE_PREVIEW,
      arguments: <String, dynamic>{'shareUrl': shareUrl, 'title': ''},
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url.trim();
    if (url.isEmpty) {
      return Center(
        child: Text(
          '暂无可打开的搜索链接',
          style: TextStyle(fontSize: 14.sp, color: AppThemeColors.textMuted),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          border: Border.all(color: AppThemeColors.border),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          children: [
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(
                value: _progress,
                minHeight: 2.h,
                backgroundColor: AppThemeColors.border.withValues(alpha: 0.4),
                color: AppThemeColors.primary,
              ),
            Expanded(
              child: InAppWebView(
                key: ValueKey<String>(url),
                initialUrlRequest: URLRequest(url: WebUri(url)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onProgressChanged: (_, progress) {
                  if (!mounted) return;
                  setState(() => _progress = progress / 100);
                },
                onLoadStop: (_, _) {
                  if (!mounted) return;
                  setState(() => _progress = 1);
                },
                shouldOverrideUrlLoading: (_, navigationAction) async {
                  final target = navigationAction.request.url?.toString() ?? '';
                  final shareUrl = _quarkSharePattern
                      .firstMatch(target)
                      ?.group(0);
                  if (shareUrl != null) {
                    _openSharePreview(shareUrl);
                    return NavigationActionPolicy.CANCEL;
                  }
                  final scheme =
                      navigationAction.request.url?.scheme.toLowerCase() ?? '';
                  if (scheme.isEmpty ||
                      scheme == 'http' ||
                      scheme == 'https' ||
                      scheme == 'about') {
                    return NavigationActionPolicy.ALLOW;
                  }
                  return NavigationActionPolicy.CANCEL;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
