import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';

class QuarkCookieWebLoginView extends StatefulWidget {
  const QuarkCookieWebLoginView({super.key, this.resetSessionOnOpen = false});

  final bool resetSessionOnOpen;

  @override
  State<QuarkCookieWebLoginView> createState() =>
      _QuarkCookieWebLoginViewState();
}

class _QuarkCookieWebLoginViewState extends State<QuarkCookieWebLoginView> {
  static final WebUri _blankUri = WebUri('about:blank');
  static final WebUri _initialUri = WebUri('https://pan.quark.cn/');
  static final List<WebUri> _cookieScopes = <WebUri>[
    WebUri('https://pan.quark.cn/'),
    WebUri('https://drive-pc.quark.cn/'),
    WebUri('https://drive-m.quark.cn/'),
    WebUri('https://quark.cn/'),
  ];
  static const Set<String> _requiredCookieNames = <String>{'__puus', '__pus'};
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

  final CookieManager _cookieManager = CookieManager.instance();

  InAppWebViewController? _webViewController;
  Timer? _cookieWatchTimer;

  double _progress = 0;
  bool _checking = false;
  bool _canReadCookies = false;

  @override
  void initState() {
    super.initState();
    _cookieWatchTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _tryCaptureCookies(),
    );
  }

  @override
  void dispose() {
    _cookieWatchTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryCaptureCookies() async {
    if (_checking || !mounted || !_canReadCookies) {
      return;
    }
    _checking = true;
    try {
      final cookies = await _readQuarkCookies();
      if (!mounted) {
        return;
      }
      if (!_hasRequiredCookies(cookies)) {
        return;
      }
      final cookieString = _serializeCookies(cookies);
      if (cookieString.isEmpty) {
        return;
      }
      Get.back<String>(result: cookieString);
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      _checking = false;
    }
  }

  Future<Map<String, String>> _readQuarkCookies() async {
    final Map<String, String> values = <String, String>{};
    for (final scope in _cookieScopes) {
      final cookies = await _cookieManager.getCookies(url: scope);
      for (final cookie in cookies) {
        final name = cookie.name.trim();
        final value = cookie.value.trim();
        if (name.isEmpty || value.isEmpty) {
          continue;
        }
        values.putIfAbsent(name, () => value);
      }
    }
    return values;
  }

  bool _hasRequiredCookies(Map<String, String> cookies) {
    for (final name in _requiredCookieNames) {
      if (cookies.containsKey(name)) {
        return true;
      }
    }
    return false;
  }

  String _serializeCookies(Map<String, String> cookies) {
    final parts = <String>[];
    for (final entry in cookies.entries) {
      parts.add('${entry.key}=${entry.value}');
    }
    return parts.join('; ');
  }

  Future<void> _openInitialPage() async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }
    if (widget.resetSessionOnOpen) {
      for (final scope in _cookieScopes) {
        await _cookieManager.deleteCookies(url: scope);
      }
    }
    await controller.loadUrl(urlRequest: URLRequest(url: _initialUri));
  }

  Future<void> _resetQuarkSession() async {
    for (final scope in _cookieScopes) {
      await _cookieManager.deleteCookies(url: scope);
    }
    await _webViewController?.loadUrl(urlRequest: URLRequest(url: _initialUri));
    if (!mounted) {
      return;
    }
    setState(() {
      _canReadCookies = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: const Text('夸克网页登录')),
      body: Column(
        children: [
          if (_progress > 0 && _progress < 1)
            LinearProgressIndicator(
              value: _progress,
              minHeight: 2.h,
              backgroundColor: AppThemeColors.surfaceSunken,
              color: AppThemeColors.primary,
            ),
          Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
              decoration: BoxDecoration(
                color: AppThemeColors.surface,
                border: Border.all(color: AppThemeColors.border),
              ),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: _blankUri),
                initialSettings: InAppWebViewSettings(
                  isInspectable: true,
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  useHybridComposition: false,
                  thirdPartyCookiesEnabled: true,
                  clearCache: false,
                  clearSessionCache: false,
                  allowsInlineMediaPlayback: true,
                  transparentBackground: false,
                  mediaPlaybackRequiresUserGesture: false,
                  userAgent: _desktopUserAgent,
                ),
                onWebViewCreated: (controller) async {
                  _webViewController = controller;
                  await _openInitialPage();
                },
                onLoadStart: (_, url) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _canReadCookies = true;
                  });
                },
                onProgressChanged: (_, progress) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _progress = progress / 100;
                  });
                },
                onLoadStop: (_, url) async {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _progress = 1;
                    _canReadCookies = true;
                  });
                  await _tryCaptureCookies();
                },
                shouldOverrideUrlLoading: (_, navigationAction) async {
                  final uri = navigationAction.request.url;
                  final scheme = uri?.scheme.toLowerCase();
                  if (scheme == null ||
                      scheme.isEmpty ||
                      scheme == 'http' ||
                      scheme == 'https') {
                    return NavigationActionPolicy.ALLOW;
                  }
                  return NavigationActionPolicy.CANCEL;
                },
                onCreateWindow: (controller, createWindowAction) async {
                  final request = createWindowAction.request;
                  final targetUrl = request.url;
                  if (targetUrl != null) {
                    await controller.loadUrl(urlRequest: request);
                  }
                  return false;
                },
                onReceivedError: (_, request, error) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _canReadCookies = true;
                  });
                },
                onReceivedHttpError: (_, request, errorResponse) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _canReadCookies = true;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetQuarkSession,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(48.h),
                  side: const BorderSide(color: AppThemeColors.borderStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: const Text('重新登录'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: FilledButton(
                onPressed: _tryCaptureCookies,
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(48.h),
                  backgroundColor: AppThemeColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: const Text('检测并保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
