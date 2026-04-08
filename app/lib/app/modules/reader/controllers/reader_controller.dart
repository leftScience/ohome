import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/api/quark.dart';

class ReaderThemePreset {
  const ReaderThemePreset({
    required this.id,
    required this.label,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.overlayColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.dividerColor,
  });

  final String id;
  final String label;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color overlayColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color dividerColor;

  EpubTheme toEpubTheme() {
    final backgroundHex = _hex(backgroundColor);
    final textHex = _hex(textColor);
    final headingHex = _hex(Color.alphaBlend(
      const Color(0x14000000),
      textColor,
    ));

    return EpubTheme.custom(
      backgroundDecoration: BoxDecoration(color: backgroundColor),
      foregroundColor: textColor,
      customCss: <String, dynamic>{
        'html, body, div, section, article, main': <String, String>{
          'background': '$backgroundHex !important',
          'color': '$textHex !important',
        },
        'body': <String, String>{
          'font-family':
              '"AlibabaPuHuiTi", "Noto Serif SC", "Source Han Serif SC", serif',
          'font-weight': '500',
          'line-height': '1.95',
          'letter-spacing': '0.015em',
          'padding': '0 10px',
          'background': '$backgroundHex !important',
          'color': '$textHex !important',
          '-webkit-text-fill-color': '$textHex !important',
        },
        'p': <String, String>{
          'margin': '0 0 1.15em 0',
          'text-indent': '2em',
          'color': '$textHex !important',
          '-webkit-text-fill-color': '$textHex !important',
        },
        'h1, h2, h3, h4, h5, h6': <String, String>{
          'color': '$headingHex !important',
          '-webkit-text-fill-color': '$headingHex !important',
          'line-height': '1.45',
          'font-weight': '700',
        },
        'span, li, blockquote, code, pre': <String, String>{
          'color': '$textHex !important',
          '-webkit-text-fill-color': '$textHex !important',
        },
        'a': <String, String>{
          'color': '$textHex !important',
          '-webkit-text-fill-color': '$textHex !important',
          'text-decoration': 'none',
        },
      },
    );
  }

  static String _hex(Color color) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}';
  }
}

class ReaderChapterItem {
  const ReaderChapterItem({
    required this.chapter,
    required this.depth,
    required this.index,
  });

  final EpubChapter chapter;
  final int depth;
  final int index;
}

class ReaderController extends GetxController {
  ReaderController({WebdavApi? webdavApi})
    : _webdavApi = webdavApi ?? Get.find<WebdavApi>();

  static const _fontSizeStorageKey = 'reader_epub_font_size';
  static const _themeStorageKey = 'reader_epub_theme';
  static const themePresets = <ReaderThemePreset>[
    ReaderThemePreset(
      id: 'warm',
      label: '护眼米黄',
      backgroundColor: Color(0xFFF7F1E3),
      surfaceColor: Color(0xFFF3EBD8),
      overlayColor: Color(0xCCF7F1E3),
      textColor: Color(0xFF1F1A17),
      secondaryTextColor: Color(0xFF7B6D62),
      accentColor: Color(0xFF8C6A43),
      dividerColor: Color(0x1E3A2514),
    ),
    ReaderThemePreset(
      id: 'paper',
      label: '纸张白',
      backgroundColor: Color(0xFFFFFCF5),
      surfaceColor: Color(0xFFF7F2E8),
      overlayColor: Color(0xCCFFFCF5),
      textColor: Color(0xFF191919),
      secondaryTextColor: Color(0xFF6E655D),
      accentColor: Color(0xFF506A85),
      dividerColor: Color(0x14000000),
    ),
    ReaderThemePreset(
      id: 'forest',
      label: '森林夜读',
      backgroundColor: Color(0xFF1B211D),
      surfaceColor: Color(0xFF232A25),
      overlayColor: Color(0xCC1B211D),
      textColor: Color(0xFFE7E1C8),
      secondaryTextColor: Color(0xFFB4AD95),
      accentColor: Color(0xFF7CA27C),
      dividerColor: Color(0x1FFFFFFF),
    ),
    ReaderThemePreset(
      id: 'ink',
      label: '深墨黑',
      backgroundColor: Color(0xFF111315),
      surfaceColor: Color(0xFF171A1D),
      overlayColor: Color(0xCC111315),
      textColor: Color(0xFFF1EBDC),
      secondaryTextColor: Color(0xFFB6AFA1),
      accentColor: Color(0xFF9A8C6D),
      dividerColor: Color(0x1FFFFFFF),
    ),
  ];

  final WebdavApi _webdavApi;

  final epubController = EpubController();
  final title = '阅读'.obs;
  final filePath = ''.obs;
  final applicationType = 'read'.obs;
  final epubUrl = ''.obs;
  final loading = true.obs;
  final viewerLoading = true.obs;
  final error = ''.obs;
  final progress = 0.0.obs;
  final currentCfi = ''.obs;
  final chapters = <EpubChapter>[].obs;
  final chapterItems = <ReaderChapterItem>[].obs;
  final fontSize = 16.0.obs;
  final selectedThemeId = 'warm'.obs;
  final currentChapterHref = ''.obs;

  SharedPreferences? _preferences;
  Timer? _persistTimer;
  Timer? _chapterSyncTimer;
  String? _initialCfi;
  late EpubDisplaySettings displaySettings;

  String? get initialCfi => _initialCfi;
  ReaderThemePreset get activeTheme => themePresets.firstWhere(
    (item) => item.id == selectedThemeId.value,
    orElse: () => themePresets.first,
  );

  bool get canOpenBook =>
      error.value.trim().isEmpty && epubUrl.value.trim().isNotEmpty;

  int get currentChapterIndex {
    final currentHref = currentChapterHref.value.trim();
    if (currentHref.isEmpty) return -1;

    for (final item in chapterItems) {
      if (_isSameChapterHref(item.chapter.href, currentHref)) {
        return item.index;
      }
    }
    return -1;
  }

  String get currentChapterTitle {
    final index = currentChapterIndex;
    if (index < 0 || index >= chapterItems.length) {
      return '未定位到当前章节';
    }
    final title = chapterItems[index].chapter.title.trim();
    return title.isEmpty ? '当前章节' : title;
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(_prepareReader());
  }

  Future<void> retry() => _prepareReader();

  Future<void> openChapter(EpubChapter chapter) async {
    final href = chapter.href.trim();
    if (href.isEmpty) return;
    epubController.display(cfi: href);
    Get.back<void>();
  }

  Future<void> goNextPage() async {
    if (!canOpenBook || viewerLoading.value) return;
    epubController.next();
  }

  Future<void> goPreviousPage() async {
    if (!canOpenBook || viewerLoading.value) return;
    epubController.prev();
  }

  Future<void> increaseFontSize() async {
    await _updateFontSize(fontSize.value + 1);
  }

  Future<void> decreaseFontSize() async {
    await _updateFontSize(fontSize.value - 1);
  }

  Future<void> applyTheme(String themeId) async {
    ReaderThemePreset? nextTheme;
    for (final item in themePresets) {
      if (item.id == themeId) {
        nextTheme = item;
        break;
      }
    }
    if (nextTheme == null || nextTheme.id == selectedThemeId.value) return;

    selectedThemeId.value = nextTheme.id;
    await _preferences?.setString(_themeStorageKey, nextTheme.id);
    if (canOpenBook) {
      await epubController.updateTheme(theme: nextTheme.toEpubTheme());
    }
  }

  Future<void> onEpubLoaded() async {
    await epubController.updateTheme(theme: activeTheme.toEpubTheme());
    await epubController.setFontSize(fontSize: fontSize.value);
    viewerLoading.value = false;
    _scheduleChapterSync();
  }

  void onChaptersLoaded(List<EpubChapter> items) {
    chapters.assignAll(items);
    chapterItems.assignAll(_flattenChapters(items));
    _scheduleChapterSync();
  }

  void onRelocated(EpubLocation location) {
    progress.value = location.progress.clamp(0.0, 1.0);
    currentCfi.value = location.startCfi.trim();
    _schedulePersistReadingPosition();
    _scheduleChapterSync();
  }

  Future<void> _prepareReader() async {
    loading.value = true;
    viewerLoading.value = true;
    error.value = '';
    progress.value = 0;
    currentCfi.value = '';
    currentChapterHref.value = '';
    chapters.clear();
    chapterItems.clear();

    try {
      _applyArguments(Get.arguments);
      final path = filePath.value.trim();
      final app = applicationType.value.trim();

      if (path.isEmpty) {
        throw Exception('文件路径不能为空');
      }
      if (app.isEmpty) {
        throw Exception('应用类型不能为空');
      }
      if (!_isEpub(path)) {
        throw Exception('当前仅支持 EPUB 文件阅读');
      }

      _preferences ??= await SharedPreferences.getInstance();

      final resolvedFontSize =
          _preferences?.getDouble(_fontSizeStorageKey) ??
          _preferences?.getInt(_fontSizeStorageKey)?.toDouble() ??
          16.0;
      fontSize.value = resolvedFontSize.clamp(12.0, 30.0);
      final resolvedThemeId =
          _preferences?.getString(_themeStorageKey)?.trim() ?? themePresets.first.id;
      selectedThemeId.value = themePresets.any((item) => item.id == resolvedThemeId)
          ? resolvedThemeId
          : themePresets.first.id;
      _initialCfi = _preferences?.getString(_positionStorageKey)?.trim();
      if (_initialCfi?.isEmpty ?? true) {
        _initialCfi = null;
      }

      displaySettings = EpubDisplaySettings(
        fontSize: fontSize.value.round(),
        flow: EpubFlow.paginated,
        spread: EpubSpread.none,
        manager: EpubManager.continuous,
        snap: true,
        useSnapAnimationAndroid: false,
        theme: activeTheme.toEpubTheme(),
      );

      epubUrl.value = _webdavApi.buildFileStreamUrl(
        applicationType: app,
        path: path,
      );
      if (epubUrl.value.trim().isEmpty) {
        throw Exception('EPUB 地址生成失败');
      }
    } catch (e) {
      error.value = '加载 EPUB 失败：$e';
      epubUrl.value = '';
    } finally {
      loading.value = false;
    }
  }

  void _applyArguments(dynamic arguments) {
    if (arguments is! Map) return;

    final nextTitle = (arguments['title'] ?? '').toString().trim();
    final nextPath = (arguments['filePath'] ?? '').toString().trim();
    final nextApplicationType =
        (arguments['applicationType'] ?? '').toString().trim();

    if (nextTitle.isNotEmpty) {
      title.value = nextTitle;
    }
    if (nextPath.isNotEmpty) {
      filePath.value = nextPath;
    }
    if (nextApplicationType.isNotEmpty) {
      applicationType.value = nextApplicationType;
    }
  }

  bool _isEpub(String value) {
    return value.trim().toLowerCase().endsWith('.epub');
  }

  String get _positionStorageKey {
    final encodedPath = base64Url.encode(utf8.encode(filePath.value.trim()));
    return 'reader_epub_cfi_$encodedPath';
  }

  void _schedulePersistReadingPosition() {
    final cfi = currentCfi.value.trim();
    if (cfi.isEmpty) return;

    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 800), () async {
      await _preferences?.setString(_positionStorageKey, cfi);
    });
  }

  void _scheduleChapterSync() {
    _chapterSyncTimer?.cancel();
    _chapterSyncTimer = Timer(const Duration(milliseconds: 250), () async {
      final href = await _readCurrentChapterHref();
      if (href.isEmpty) return;
      currentChapterHref.value = href;
    });
  }

  Future<String> _readCurrentChapterHref() async {
    final webViewController = epubController.webViewController;
    if (webViewController == null) return '';

    try {
      final result = await webViewController.evaluateJavascript(
        source: '''
          (() => {
            try {
              const normalizeHref = (value) => {
                let text = String(value || '').trim().replaceAll('\\\\', '/');
                while (text.startsWith('./')) {
                  text = text.substring(2);
                }
                return text;
              };

              const splitHref = (value) => {
                const normalized = normalizeHref(value);
                const hashIndex = normalized.indexOf('#');
                if (hashIndex < 0) {
                  return { path: normalized, fragment: '' };
                }
                return {
                  path: normalized.substring(0, hashIndex),
                  fragment: normalized.substring(hashIndex + 1),
                };
              };

              const flattenToc = (items, result = []) => {
                for (const item of items || []) {
                  result.push(item);
                  if (item?.subitems?.length) {
                    flattenToc(item.subitems, result);
                  }
                }
                return result;
              };

              const location = (typeof rendition !== 'undefined' && rendition)
                ? (rendition.currentLocation ? rendition.currentLocation() : rendition.location)
                : null;
              const rawHref = location?.start?.href ?? location?.href ?? '';
              const currentCfi = location?.start?.cfi ?? '';
              const toc = flattenToc(book?.navigation?.toc || []);
              if (!rawHref || !toc.length) {
                return rawHref || '';
              }

              const current = splitHref(rawHref);
              const candidates = toc.filter((item) => {
                const target = splitHref(item?.href);
                return target.path && target.path === current.path;
              });
              if (!candidates.length) {
                return rawHref;
              }
              if (candidates.length === 1) {
                return candidates[0]?.href || rawHref;
              }
              if (!currentCfi) {
                return candidates[0]?.href || rawHref;
              }

              const cfi = new ePub.CFI(currentCfi);
              const spineItem = book?.spine?.get(cfi.spinePos);
              const doc = spineItem?.document;
              if (!doc) {
                return candidates[0]?.href || rawHref;
              }
              const range = cfi.toRange(doc);
              const currentNode = range?.startContainer;
              if (!currentNode) {
                return candidates[0]?.href || rawHref;
              }

              let bestHref = candidates[0]?.href || rawHref;
              for (const item of candidates) {
                const target = splitHref(item?.href);
                if (!target.fragment) {
                  bestHref = item?.href || bestHref;
                  continue;
                }

                const fragment = decodeURIComponent(target.fragment);
                const escapedFragment = fragment.replace(/"/g, '\\"');
                const anchor =
                  doc.getElementById(fragment) ||
                  doc.querySelector('[id="' + escapedFragment + '"]');
                if (!anchor) {
                  continue;
                }

                if (anchor === currentNode || anchor.contains?.(currentNode)) {
                  bestHref = item?.href || bestHref;
                  continue;
                }

                const position = anchor.compareDocumentPosition(currentNode);
                const isBeforeCurrent =
                  (position & Node.DOCUMENT_POSITION_FOLLOWING) !== 0;
                if (isBeforeCurrent) {
                  bestHref = item?.href || bestHref;
                }
              }

              return bestHref || rawHref;
            } catch (error) {
              return '';
            }
          })();
        ''',
      );
      return (result ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  List<ReaderChapterItem> _flattenChapters(List<EpubChapter> source) {
    final items = <ReaderChapterItem>[];

    void visit(List<EpubChapter> nodes, int depth) {
      for (final chapter in nodes) {
        items.add(
          ReaderChapterItem(
            chapter: chapter,
            depth: depth,
            index: items.length,
          ),
        );
        if (chapter.subitems.isNotEmpty) {
          visit(chapter.subitems, depth + 1);
        }
      }
    }

    visit(source, 0);
    return items;
  }

  bool _isSameChapterHref(String left, String right) {
    final exactLeft = _normalizeChapterHref(left, keepFragment: true);
    final exactRight = _normalizeChapterHref(right, keepFragment: true);
    if (exactLeft.isNotEmpty &&
        exactRight.isNotEmpty &&
        (exactLeft == exactRight ||
            exactLeft.endsWith(exactRight) ||
            exactRight.endsWith(exactLeft))) {
      return true;
    }

    final normalizedLeft = _normalizeChapterHref(left, keepFragment: false);
    final normalizedRight = _normalizeChapterHref(right, keepFragment: false);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) return false;
    return normalizedLeft == normalizedRight;
  }

  String _normalizeChapterHref(String value, {required bool keepFragment}) {
    var normalized = value.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) return '';
    final hashIndex = normalized.indexOf('#');
    if (!keepFragment && hashIndex >= 0) {
      normalized = normalized.substring(0, hashIndex);
    }
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }

  Future<void> _updateFontSize(double nextValue) async {
    final normalized = nextValue.clamp(12.0, 30.0);
    if ((normalized - fontSize.value).abs() < 0.01) return;

    fontSize.value = normalized;
    await _preferences?.setDouble(_fontSizeStorageKey, normalized);
    await epubController.setFontSize(fontSize: normalized);
  }

  @override
  void onClose() {
    _persistTimer?.cancel();
    _chapterSyncTimer?.cancel();
    final cfi = currentCfi.value.trim();
    if (cfi.isNotEmpty) {
      unawaited(_preferences?.setString(_positionStorageKey, cfi) ?? Future.value());
    }
    super.onClose();
  }
}
