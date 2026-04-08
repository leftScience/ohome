import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:get/get.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/api/quark.dart';
import '../../../services/media_history_service.dart';

enum ReaderFileFormat { unknown, epub, txt, pdf }

enum ReaderNavKind { chapter, segment, page }

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
    final headingHex = _hex(
      Color.alphaBlend(const Color(0x14000000), textColor),
    );

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

class ReaderNavItem {
  const ReaderNavItem({
    required this.kind,
    required this.index,
    required this.depth,
    required this.label,
    this.href,
  });

  final ReaderNavKind kind;
  final int index;
  final int depth;
  final String label;
  final String? href;
}

class ReaderRestoreState {
  const ReaderRestoreState({
    this.epubCfi,
    this.txtSegmentIndex,
    this.pdfPageNumber,
  });

  final String? epubCfi;
  final int? txtSegmentIndex;
  final int? pdfPageNumber;
}

class ReaderTxtSegment {
  const ReaderTxtSegment({
    required this.index,
    required this.title,
    required this.content,
    required this.segmentationMode,
  });

  final int index;
  final String title;
  final String content;
  final String segmentationMode;
}

class ReaderTxtPage {
  const ReaderTxtPage({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
  });

  final int index;
  final int start;
  final int end;
  final String text;
}

class _ReaderTxtPaginationResult {
  const _ReaderTxtPaginationResult({
    required this.pages,
    required this.viewport,
  });

  final List<ReaderTxtPage> pages;
  final Size viewport;
}

class ReaderController extends GetxController {
  ReaderController({WebdavApi? webdavApi, MediaHistoryService? historyService})
    : _webdavApi = webdavApi ?? Get.find<WebdavApi>(),
      _historyService =
          historyService ??
          (Get.isRegistered<MediaHistoryService>()
              ? Get.find<MediaHistoryService>()
              : null);

  static const _fontSizeStorageKey = 'reader_epub_font_size';
  static const _themeStorageKey = 'reader_epub_theme';
  static const _historyDuration = Duration(milliseconds: 1000000);
  static const _historyPersistDebounceDuration = Duration(milliseconds: 700);
  static const _txtTargetSegmentLength = 12000;
  static const _txtHardSegmentLength = 16000;
  static const _txtPaginationRefineWindow = 80;
  static const _tapMaxDuration = Duration(milliseconds: 320);
  static const _tapNavigationCooldown = Duration(milliseconds: 320);
  static const _tapMaxMoveDistance = 0.05;
  static const _tapLeftZoneMaxX = 0.28;
  static const _tapRightZoneMinX = 0.52;
  static const _txtLineHeight = 1.95;
  static const _txtLetterSpacing = 0.24;
  static const txtPagePadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 20,
  );
  static final RegExp _txtHeadingPattern = RegExp(
    r'^(?:(?:第[0-9零一二三四五六七八九十百千两〇]+(?:章|卷|回|节|篇|集|部|季|话))|(?:chapter\s+[0-9ivxlcdm]+)|(?:序章|楔子|尾声|后记|番外))(?:(?:[\s:：.\-].*)?)$',
    caseSensitive: false,
  );
  static const _txtRefineBreakChars = <String>{
    '\n',
    '。',
    '！',
    '？',
    '；',
    '：',
    '…',
    '.',
    '!',
    '?',
    ';',
    ',',
    '，',
  };
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
  final MediaHistoryService? _historyService;

  final epubController = EpubController();
  final title = '阅读'.obs;
  final filePath = ''.obs;
  final applicationType = 'read'.obs;
  final readerFormat = ReaderFileFormat.unknown.obs;
  final epubUrl = ''.obs;
  final loading = true.obs;
  final viewerLoading = true.obs;
  final error = ''.obs;
  final progress = 0.0.obs;
  final currentCfi = ''.obs;
  final chapters = <EpubChapter>[].obs;
  final chapterItems = <ReaderChapterItem>[].obs;
  final navigationItems = <ReaderNavItem>[].obs;
  final txtSegments = <ReaderTxtSegment>[].obs;
  final currentTxtSegmentIndex = 0.obs;
  final currentTxtPageIndex = 0.obs;
  final txtPageCount = 0.obs;
  final txtPaginationReady = false.obs;
  final txtPageControllerVersion = 0.obs;
  final fontSize = 16.0.obs;
  final selectedThemeId = 'warm'.obs;
  final currentChapterHref = ''.obs;
  final currentPdfPage = 1.obs;
  final pdfPageCount = 0.obs;

  SharedPreferences? _preferences;
  Timer? _persistTimer;
  Timer? _chapterSyncTimer;
  EpubLocation? _lastLocation;
  ReaderRestoreState _restoreState = const ReaderRestoreState();
  int _persistToken = 0;
  int _chapterSyncToken = 0;
  int _initialPdfPage = 1;
  Size? _txtViewport;
  PageController? _txtPageController;
  PdfController? _pdfController;
  PdfDocument? _pdfDocument;
  EpubDisplaySettings? displaySettings;
  final Map<String, _ReaderTxtPaginationResult> _txtPaginationCache = {};
  Offset? _touchDownOffset;
  DateTime? _touchDownAt;
  DateTime? _lastTapNavigationAt;

  String? get initialCfi => _restoreState.epubCfi;
  PdfController? get pdfController => _pdfController;
  PageController? get txtPageController => _txtPageController;
  ReaderThemePreset get activeTheme => themePresets.firstWhere(
    (item) => item.id == selectedThemeId.value,
    orElse: () => themePresets.first,
  );
  TextStyle get txtTextStyle => TextStyle(
    fontFamily: 'AlibabaPuHuiTi',
    fontSize: fontSize.value,
    height: _txtLineHeight,
    letterSpacing: _txtLetterSpacing,
    color: activeTheme.textColor,
    fontWeight: FontWeight.w500,
  );

  @override
  void onReady() {
    super.onReady();
    unawaited(_prepareReader());
  }

  Future<void> retry() => _prepareReader();

  bool get canOpenReader {
    if (error.value.trim().isNotEmpty) return false;
    switch (readerFormat.value) {
      case ReaderFileFormat.epub:
        return epubUrl.value.trim().isNotEmpty;
      case ReaderFileFormat.txt:
        return txtSegments.isNotEmpty;
      case ReaderFileFormat.pdf:
        return _pdfController != null;
      case ReaderFileFormat.unknown:
        return false;
    }
  }

  bool get canAdjustFontSize =>
      canOpenReader && readerFormat.value != ReaderFileFormat.pdf;

  bool get canSelectTheme =>
      canOpenReader && readerFormat.value != ReaderFileFormat.pdf;

  bool get canShowNavigation => navigationItems.isNotEmpty;

  String get navigationTooltip {
    switch (readerFormat.value) {
      case ReaderFileFormat.txt:
        return '选集';
      case ReaderFileFormat.pdf:
        return '页码';
      case ReaderFileFormat.epub:
      case ReaderFileFormat.unknown:
        return '目录';
    }
  }

  int get currentNavigationIndex {
    switch (readerFormat.value) {
      case ReaderFileFormat.epub:
        return currentChapterIndex;
      case ReaderFileFormat.txt:
        return txtSegments.isEmpty ? -1 : currentTxtSegmentIndex.value;
      case ReaderFileFormat.pdf:
        return pdfPageCount.value <= 0 ? -1 : currentPdfPage.value - 1;
      case ReaderFileFormat.unknown:
        return -1;
    }
  }

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
    final currentTitle = chapterItems[index].chapter.title.trim();
    return currentTitle.isEmpty ? '当前章节' : currentTitle;
  }

  ReaderTxtSegment? get currentTxtSegment {
    if (currentTxtSegmentIndex.value < 0 ||
        currentTxtSegmentIndex.value >= txtSegments.length) {
      return null;
    }
    return txtSegments[currentTxtSegmentIndex.value];
  }

  List<ReaderTxtPage> get currentTxtPages =>
      _currentTxtPagination?.pages ?? const <ReaderTxtPage>[];

  Future<void> openNavigationItem(ReaderNavItem item) async {
    switch (item.kind) {
      case ReaderNavKind.chapter:
        final href = item.href?.trim() ?? '';
        if (href.isEmpty) return;
        epubController.display(cfi: href);
        return;
      case ReaderNavKind.segment:
        await openTxtSegment(item.index);
        return;
      case ReaderNavKind.page:
        await openPdfPage(item.index + 1);
        return;
    }
  }

  Future<void> openTxtSegment(int segmentIndex) async {
    if (readerFormat.value != ReaderFileFormat.txt) return;
    if (segmentIndex < 0 || segmentIndex >= txtSegments.length) return;

    currentTxtSegmentIndex.value = segmentIndex;
    currentTxtPageIndex.value = 0;
    _updateTxtProgress();
    _rebuildCurrentTxtPagination(resetToFirstPage: true);
    _schedulePersistReadingState();
  }

  Future<void> openPdfPage(int pageNumber) async {
    final controller = _pdfController;
    if (readerFormat.value != ReaderFileFormat.pdf || controller == null) {
      return;
    }
    final total = pdfPageCount.value;
    final target = _clampPdfPage(pageNumber, total);
    if (total > 0 && target == currentPdfPage.value) return;
    await controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    currentPdfPage.value = target;
    _updatePdfProgress();
    _schedulePersistReadingState();
  }

  Future<void> goNextPage() async {
    if (!canOpenReader) return;

    switch (readerFormat.value) {
      case ReaderFileFormat.epub:
        if (viewerLoading.value) return;
        epubController.next();
        return;
      case ReaderFileFormat.txt:
        final controller = _txtPageController;
        if (controller == null || currentTxtPages.isEmpty) return;
        final currentPage = currentTxtPageIndex.value;
        if (currentPage < currentTxtPages.length - 1) {
          await controller.animateToPage(
            currentPage + 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        } else if (currentTxtSegmentIndex.value < txtSegments.length - 1) {
          await openTxtSegment(currentTxtSegmentIndex.value + 1);
        }
        return;
      case ReaderFileFormat.pdf:
        final controller = _pdfController;
        if (controller == null || currentPdfPage.value >= pdfPageCount.value) {
          return;
        }
        await controller.nextPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        return;
      case ReaderFileFormat.unknown:
        return;
    }
  }

  Future<void> goPreviousPage() async {
    if (!canOpenReader) return;

    switch (readerFormat.value) {
      case ReaderFileFormat.epub:
        if (viewerLoading.value) return;
        epubController.prev();
        return;
      case ReaderFileFormat.txt:
        final controller = _txtPageController;
        if (controller == null || currentTxtPages.isEmpty) return;
        final currentPage = currentTxtPageIndex.value;
        if (currentPage > 0) {
          await controller.animateToPage(
            currentPage - 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        } else if (currentTxtSegmentIndex.value > 0) {
          currentTxtSegmentIndex.value -= 1;
          _rebuildCurrentTxtPagination(
            desiredPage: math.max(
              0,
              (_paginationForSegment(
                        currentTxtSegmentIndex.value,
                      )?.pages.length ??
                      1) -
                  1,
            ),
          );
          _updateTxtProgress();
          _schedulePersistReadingState();
        }
        return;
      case ReaderFileFormat.pdf:
        final controller = _pdfController;
        if (controller == null || currentPdfPage.value <= 1) return;
        await controller.previousPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        return;
      case ReaderFileFormat.unknown:
        return;
    }
  }

  void onReaderTouchDown(double x, double y) {
    if (!canOpenReader || viewerLoading.value) {
      return;
    }

    _touchDownOffset = _normalizeTouchPoint(x, y);
    _touchDownAt = DateTime.now();
  }

  void cancelReaderTouch() {
    _touchDownAt = null;
    _touchDownOffset = null;
  }

  Future<void> onReaderTouchUp(double x, double y) async {
    final touchDownAt = _touchDownAt;
    final touchDownOffset = _touchDownOffset;
    cancelReaderTouch();

    if (!canOpenReader ||
        viewerLoading.value ||
        touchDownAt == null ||
        touchDownOffset == null) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(touchDownAt) > _tapMaxDuration) {
      return;
    }

    final touchUpOffset = _normalizeTouchPoint(x, y);
    final moveX = (touchUpOffset.dx - touchDownOffset.dx).abs();
    final moveY = (touchUpOffset.dy - touchDownOffset.dy).abs();
    if (moveX > _tapMaxMoveDistance || moveY > _tapMaxMoveDistance) {
      return;
    }

    final lastTapNavigationAt = _lastTapNavigationAt;
    if (lastTapNavigationAt != null &&
        now.difference(lastTapNavigationAt) < _tapNavigationCooldown) {
      return;
    }

    if (touchUpOffset.dx >= _tapRightZoneMinX) {
      _lastTapNavigationAt = now;
      await goNextPage();
      return;
    }

    if (touchUpOffset.dx <= _tapLeftZoneMaxX) {
      _lastTapNavigationAt = now;
      await goPreviousPage();
    }
  }

  Future<void> increaseFontSize() async {
    if (!canAdjustFontSize) return;
    await _updateFontSize(fontSize.value + 1);
  }

  Future<void> decreaseFontSize() async {
    if (!canAdjustFontSize) return;
    await _updateFontSize(fontSize.value - 1);
  }

  Future<void> applyTheme(String themeId) async {
    if (readerFormat.value == ReaderFileFormat.pdf) return;

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

    if (readerFormat.value == ReaderFileFormat.epub && canOpenReader) {
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
    navigationItems.assignAll(
      chapterItems
          .map(
            (item) => ReaderNavItem(
              kind: ReaderNavKind.chapter,
              index: item.index,
              depth: item.depth,
              label: item.chapter.title.trim().isEmpty
                  ? '第 ${item.index + 1} 章'
                  : item.chapter.title.trim(),
              href: item.chapter.href,
            ),
          )
          .toList(growable: false),
    );
    _scheduleChapterSync();
  }

  void onRelocated(EpubLocation location) {
    _applyEpubLocation(location);
    _schedulePersistReadingState();
    _scheduleChapterSync();
  }

  void onPdfDocumentLoaded(PdfDocument document) {
    _pdfDocument = document;
    pdfPageCount.value = document.pagesCount;
    navigationItems.assignAll(
      List<ReaderNavItem>.generate(
        document.pagesCount,
        (index) => ReaderNavItem(
          kind: ReaderNavKind.page,
          index: index,
          depth: 0,
          label: '第 ${index + 1} 页',
        ),
        growable: false,
      ),
    );

    final targetPage = _clampPdfPage(_initialPdfPage, document.pagesCount);
    currentPdfPage.value = targetPage;
    _updatePdfProgress();
    viewerLoading.value = false;

    final actualPage = _pdfController?.page ?? targetPage;
    if (actualPage != targetPage) {
      unawaited(openPdfPage(targetPage));
    } else {
      _schedulePersistReadingState();
    }
  }

  void onPdfPageChanged(int page) {
    if (page <= 0) return;
    currentPdfPage.value = _clampPdfPage(page, pdfPageCount.value);
    _updatePdfProgress();
    _schedulePersistReadingState();
  }

  void onPdfDocumentError(Object loadError) {
    error.value = '加载 PDF 失败：$loadError';
    viewerLoading.value = false;
  }

  void onTxtPageChanged(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= currentTxtPages.length) return;
    if (currentTxtPageIndex.value == pageIndex) return;

    currentTxtPageIndex.value = pageIndex;
    _updateTxtProgress();
    _schedulePersistReadingState();
  }

  void updateTxtViewport(Size viewport) {
    if (readerFormat.value != ReaderFileFormat.txt) return;
    if (!_hasUsableViewport(viewport)) return;
    if (_txtViewport != null && _isSameViewport(_txtViewport!, viewport)) {
      return;
    }

    final preserveOffset = _currentTxtPageStartOffset;
    _txtViewport = viewport;
    _rebuildCurrentTxtPagination(preserveCharOffset: preserveOffset);
  }

  Future<void> _prepareReader() async {
    await _disposeReaderResources();

    loading.value = true;
    viewerLoading.value = true;
    error.value = '';
    progress.value = 0;
    title.value = '阅读';
    filePath.value = '';
    applicationType.value = 'read';
    readerFormat.value = ReaderFileFormat.unknown;

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

      readerFormat.value = _detectFormat(path);
      if (readerFormat.value == ReaderFileFormat.unknown) {
        throw Exception('当前仅支持 EPUB、TXT、PDF 文件阅读');
      }

      _preferences ??= await SharedPreferences.getInstance();
      _loadReaderPreferences();
      _restoreState = await _readRestoreState(path: path, applicationType: app);

      switch (readerFormat.value) {
        case ReaderFileFormat.epub:
          _prepareEpub(path: path, applicationType: app);
          break;
        case ReaderFileFormat.txt:
          await _prepareTxt(path: path, applicationType: app);
          break;
        case ReaderFileFormat.pdf:
          await _preparePdf(path: path, applicationType: app);
          break;
        case ReaderFileFormat.unknown:
          throw Exception('暂不支持当前文件类型');
      }
    } catch (e) {
      error.value = '加载阅读内容失败：$e';
      viewerLoading.value = false;
    } finally {
      loading.value = false;
    }
  }

  void _prepareEpub({required String path, required String applicationType}) {
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
      applicationType: applicationType,
      path: path,
    );
    if (epubUrl.value.trim().isEmpty) {
      throw Exception('EPUB 地址生成失败');
    }
  }

  Future<void> _prepareTxt({
    required String path,
    required String applicationType,
  }) async {
    final content = await _webdavApi.fetchTextFileContent(
      applicationType: applicationType,
      path: path,
    );
    final segments = _buildTxtSegments(content);
    txtSegments.assignAll(segments);
    navigationItems.assignAll(
      segments
          .map(
            (item) => ReaderNavItem(
              kind: ReaderNavKind.segment,
              index: item.index,
              depth: 0,
              label: item.title,
            ),
          )
          .toList(growable: false),
    );

    final restoreIndex = _restoreState.txtSegmentIndex ?? 0;
    currentTxtSegmentIndex.value = _clampInt(
      restoreIndex,
      0,
      math.max(0, txtSegments.length - 1),
    );
    currentTxtPageIndex.value = 0;
    txtPaginationReady.value = false;
    _updateTxtProgress();
    viewerLoading.value = false;
  }

  Future<void> _preparePdf({
    required String path,
    required String applicationType,
  }) async {
    final bytes = await _webdavApi.fetchFileBytes(
      applicationType: applicationType,
      path: path,
    );
    if (bytes.isEmpty) {
      throw Exception('PDF 内容为空');
    }

    _initialPdfPage = math.max(1, _restoreState.pdfPageNumber ?? 1);
    _pdfController = PdfController(
      document: PdfDocument.openData(Uint8List.fromList(bytes)),
      initialPage: _initialPdfPage,
    );
    currentPdfPage.value = _initialPdfPage;
    pdfPageCount.value = 0;
  }

  void _loadReaderPreferences() {
    final resolvedFontSize =
        _preferences?.getDouble(_fontSizeStorageKey) ??
        _preferences?.getInt(_fontSizeStorageKey)?.toDouble() ??
        16.0;
    fontSize.value = resolvedFontSize.clamp(12.0, 30.0);

    final resolvedThemeId =
        _preferences?.getString(_themeStorageKey)?.trim() ??
        themePresets.first.id;
    selectedThemeId.value =
        themePresets.any((item) => item.id == resolvedThemeId)
        ? resolvedThemeId
        : themePresets.first.id;
  }

  void _applyArguments(dynamic arguments) {
    if (arguments is! Map) return;

    final nextTitle = (arguments['title'] ?? '').toString().trim();
    final nextPath = (arguments['filePath'] ?? '').toString().trim();
    final nextApplicationType = (arguments['applicationType'] ?? '')
        .toString()
        .trim();

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

  ReaderFileFormat _detectFormat(String path) {
    final lower = path.trim().toLowerCase();
    if (lower.endsWith('.epub')) return ReaderFileFormat.epub;
    if (lower.endsWith('.txt')) return ReaderFileFormat.txt;
    if (lower.endsWith('.pdf')) return ReaderFileFormat.pdf;
    return ReaderFileFormat.unknown;
  }

  void _applyEpubLocation(EpubLocation location) {
    final cfi = location.startCfi.trim();
    if (cfi.isEmpty) return;
    _lastLocation = location;
    progress.value = location.progress.clamp(0.0, 1.0);
    currentCfi.value = cfi;
  }

  void _schedulePersistReadingState() {
    _persistToken += 1;
    final token = _persistToken;
    _persistTimer?.cancel();
    _persistTimer = Timer(_historyPersistDebounceDuration, () {
      unawaited(_persistReadingState(token));
    });
  }

  Future<void> _persistReadingState(int token) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (token != _persistToken) return;

    if (readerFormat.value == ReaderFileFormat.epub) {
      var location = _lastLocation;
      if (location != null && canOpenReader && !viewerLoading.value) {
        try {
          location = await epubController.getCurrentLocation();
        } catch (_) {}
      }
      if (token != _persistToken || location == null) return;
      _applyEpubLocation(location);
      await _saveEpubHistory(location);
      return;
    }

    if (readerFormat.value == ReaderFileFormat.txt) {
      await _saveTxtHistory();
      return;
    }

    if (readerFormat.value == ReaderFileFormat.pdf) {
      await _savePdfHistory();
    }
  }

  Future<ReaderRestoreState> _readRestoreState({
    required String path,
    required String applicationType,
  }) async {
    final service = _historyService;
    if (service == null || path.trim().isEmpty) {
      return const ReaderRestoreState();
    }

    try {
      final entry = await service.fetchByFolder(
        applicationType: applicationType,
        folderPath: path,
        preferFresh: true,
      );
      final extra = entry?.extra;
      final readerFormat = _stringFromExtra(
        extra,
        'readerFormat',
      )?.trim().toLowerCase();

      return ReaderRestoreState(
        epubCfi: readerFormat == null || readerFormat == 'epub'
            ? (_stringFromExtra(extra, 'restoreCfi')?.trim() ??
                  _stringFromExtra(extra, 'endCfi')?.trim() ??
                  _stringFromExtra(extra, 'cfi')?.trim())
            : null,
        txtSegmentIndex: readerFormat == null || readerFormat == 'txt'
            ? _intFromExtra(extra, 'segmentIndex')
            : null,
        pdfPageNumber: readerFormat == null || readerFormat == 'pdf'
            ? _intFromExtra(extra, 'pageNumber')
            : null,
      );
    } catch (_) {
      return const ReaderRestoreState();
    }
  }

  Future<void> _saveEpubHistory(EpubLocation location) async {
    final service = _historyService;
    final path = filePath.value.trim();
    final app = applicationType.value.trim().isEmpty
        ? 'read'
        : applicationType.value.trim();
    final bookTitle = _bookTitle;
    final cfi = location.startCfi.trim();
    if (service == null || path.isEmpty || cfi.isEmpty) return;

    try {
      await service.saveProgress(
        applicationType: app,
        folderPath: path,
        itemTitle: bookTitle,
        position: _progressPosition,
        itemPath: path,
        duration: _historyDuration,
        extra: <String, dynamic>{
          'readerFormat': 'epub',
          'cfi': cfi,
          'endCfi': location.endCfi.trim(),
          'restoreCfi': location.endCfi.trim().isEmpty
              ? cfi
              : location.endCfi.trim(),
          'restoreStrategy': 'endCfi',
          'startXpath': location.startXpath,
          'endXpath': location.endXpath,
          'progress': progress.value,
          'chapterHref': currentChapterHref.value,
          'chapterTitle': currentChapterTitle,
          'itemPath': path,
        },
      );
    } catch (_) {}
  }

  Future<void> _saveTxtHistory() async {
    final service = _historyService;
    final path = filePath.value.trim();
    if (service == null || path.isEmpty || txtSegments.isEmpty) return;

    final segment = currentTxtSegment;
    if (segment == null) return;

    try {
      await service.saveProgress(
        applicationType: applicationType.value.trim().isEmpty
            ? 'read'
            : applicationType.value.trim(),
        folderPath: path,
        itemTitle: _bookTitle,
        position: _progressPosition,
        itemPath: path,
        duration: _historyDuration,
        extra: <String, dynamic>{
          'readerFormat': 'txt',
          'segmentIndex': currentTxtSegmentIndex.value,
          'segmentTitle': segment.title,
          'segmentationMode': segment.segmentationMode,
          'totalSegments': txtSegments.length,
          'progress': progress.value,
          'itemPath': path,
        },
      );
    } catch (_) {}
  }

  Future<void> _savePdfHistory() async {
    final service = _historyService;
    final path = filePath.value.trim();
    if (service == null || path.isEmpty || pdfPageCount.value <= 0) return;

    final pageNumber = _clampPdfPage(currentPdfPage.value, pdfPageCount.value);
    try {
      await service.saveProgress(
        applicationType: applicationType.value.trim().isEmpty
            ? 'read'
            : applicationType.value.trim(),
        folderPath: path,
        itemTitle: _bookTitle,
        position: _progressPosition,
        itemPath: path,
        duration: _historyDuration,
        extra: <String, dynamic>{
          'readerFormat': 'pdf',
          'pageNumber': pageNumber,
          'pagesCount': pdfPageCount.value,
          'pageLabel': '第 $pageNumber 页',
          'progress': progress.value,
          'itemPath': path,
        },
      );
    } catch (_) {}
  }

  Duration get _progressPosition {
    final normalized = progress.value.clamp(0.0, 1.0);
    return Duration(
      milliseconds: (normalized * _historyDuration.inMilliseconds).round(),
    );
  }

  String get _bookTitle {
    final currentTitle = title.value.trim();
    if (currentTitle.isNotEmpty) {
      return currentTitle;
    }
    return _titleFromPath(filePath.value, fallback: '阅读');
  }

  void _updateTxtProgress() {
    progress.value = _computeTxtProgress();
  }

  void _updatePdfProgress() {
    if (pdfPageCount.value <= 0) {
      progress.value = 0;
      return;
    }
    progress.value = (currentPdfPage.value / pdfPageCount.value).clamp(
      0.0,
      1.0,
    );
  }

  double _computeTxtProgress() {
    if (txtSegments.isEmpty) return 0;
    final pageCount = math.max(1, currentTxtPages.length);
    final pageProgress = (currentTxtPageIndex.value + 1) / pageCount;
    return ((currentTxtSegmentIndex.value + pageProgress) / txtSegments.length)
        .clamp(0.0, 1.0);
  }

  String? _stringFromExtra(Map<String, dynamic>? extra, String key) {
    final value = extra?[key];
    return value is String ? value : null;
  }

  int? _intFromExtra(Map<String, dynamic>? extra, String key) {
    final value = extra?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String _titleFromPath(String path, {required String fallback}) {
    final normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return fallback;
    final parts = normalized
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? fallback : parts.last;
  }

  Offset _normalizeTouchPoint(double x, double y) {
    return Offset(
      math.max(0.0, math.min(1.0, x)),
      math.max(0.0, math.min(1.0, y)),
    );
  }

  void _scheduleChapterSync() {
    if (readerFormat.value != ReaderFileFormat.epub) return;

    _chapterSyncToken += 1;
    final token = _chapterSyncToken;
    _chapterSyncTimer?.cancel();
    _chapterSyncTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        if (canOpenReader && !viewerLoading.value) {
          _applyEpubLocation(await epubController.getCurrentLocation());
        }
      } catch (_) {}

      if (token != _chapterSyncToken) return;
      final href = await _readCurrentChapterHref();
      if (token != _chapterSyncToken || href.isEmpty) return;
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

  List<ReaderTxtSegment> _buildTxtSegments(String rawText) {
    final normalized = rawText
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) {
      return const <ReaderTxtSegment>[
        ReaderTxtSegment(
          index: 0,
          title: '第 1 片',
          content: '',
          segmentationMode: 'heading_or_fixed',
        ),
      ];
    }

    final headingSegments = _buildHeadingTxtSegments(normalized);
    if (headingSegments.length >= 2) {
      return headingSegments;
    }
    return _buildFixedTxtSegments(normalized);
  }

  List<ReaderTxtSegment> _buildHeadingTxtSegments(String text) {
    final segments = <ReaderTxtSegment>[];
    final lines = text.split('\n');
    final buffer = StringBuffer();
    var currentTitle = '';

    void flush() {
      final content = buffer.toString().trim();
      if (content.isEmpty) return;
      segments.add(
        ReaderTxtSegment(
          index: segments.length,
          title: currentTitle.trim().isEmpty
              ? '第 ${segments.length + 1} 片'
              : currentTitle.trim(),
          content: content,
          segmentationMode: 'heading_or_fixed',
        ),
      );
      buffer.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (_isTxtHeading(trimmed)) {
        if (buffer.toString().trim().isNotEmpty) {
          flush();
        }
        currentTitle = trimmed;
        buffer.write(trimmed);
        buffer.write('\n\n');
        continue;
      }
      buffer.write(line.trimRight());
      buffer.write('\n');
    }

    flush();
    return segments;
  }

  List<ReaderTxtSegment> _buildFixedTxtSegments(String text) {
    final paragraphs = _splitTxtParagraphs(text);
    if (paragraphs.isEmpty) {
      return const <ReaderTxtSegment>[
        ReaderTxtSegment(
          index: 0,
          title: '第 1 片',
          content: '',
          segmentationMode: 'heading_or_fixed',
        ),
      ];
    }

    final segments = <ReaderTxtSegment>[];
    final buffer = <String>[];
    var currentLength = 0;

    void flush() {
      final content = buffer.join('\n\n').trim();
      if (content.isEmpty) return;
      segments.add(
        ReaderTxtSegment(
          index: segments.length,
          title: '第 ${segments.length + 1} 片',
          content: content,
          segmentationMode: 'heading_or_fixed',
        ),
      );
      buffer.clear();
      currentLength = 0;
    }

    for (final paragraph in paragraphs) {
      final normalized = paragraph.trim();
      if (normalized.isEmpty) continue;

      if (normalized.length > _txtHardSegmentLength) {
        if (buffer.isNotEmpty) {
          flush();
        }
        for (final chunk in _splitLongParagraph(normalized)) {
          segments.add(
            ReaderTxtSegment(
              index: segments.length,
              title: '第 ${segments.length + 1} 片',
              content: chunk,
              segmentationMode: 'heading_or_fixed',
            ),
          );
        }
        continue;
      }

      if (buffer.isNotEmpty &&
          (currentLength + normalized.length > _txtHardSegmentLength ||
              (currentLength >= _txtTargetSegmentLength &&
                  currentLength + normalized.length >
                      _txtTargetSegmentLength))) {
        flush();
      }

      buffer.add(normalized);
      currentLength += normalized.length;
    }

    if (buffer.isNotEmpty) {
      flush();
    }

    if (segments.isEmpty) {
      return <ReaderTxtSegment>[
        ReaderTxtSegment(
          index: 0,
          title: '第 1 片',
          content: text,
          segmentationMode: 'heading_or_fixed',
        ),
      ];
    }

    return segments;
  }

  List<String> _splitTxtParagraphs(String text) {
    final primary = text
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (primary.length > 1) {
      return primary;
    }
    return text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _splitLongParagraph(String paragraph) {
    final chunks = <String>[];
    var start = 0;
    while (start < paragraph.length) {
      var end = math.min(paragraph.length, start + _txtHardSegmentLength);
      if (end < paragraph.length) {
        final refined = _refineTxtPageEnd(paragraph, start, end);
        if (refined > start) {
          end = refined;
        }
      }
      chunks.add(paragraph.substring(start, end).trim());
      start = end;
    }
    return chunks;
  }

  bool _isTxtHeading(String value) {
    if (value.isEmpty || value.length > 48) {
      return false;
    }
    return _txtHeadingPattern.hasMatch(value);
  }

  void _rebuildCurrentTxtPagination({
    int? preserveCharOffset,
    bool resetToFirstPage = false,
    int? desiredPage,
  }) {
    if (readerFormat.value != ReaderFileFormat.txt ||
        _txtViewport == null ||
        currentTxtSegment == null) {
      txtPaginationReady.value = false;
      txtPageCount.value = 0;
      _disposeTxtPageController();
      return;
    }

    final segment = currentTxtSegment!;
    final cacheKey = _txtPaginationCacheKey(
      segmentIndex: segment.index,
      viewport: _txtViewport!,
      fontSize: fontSize.value,
    );

    final pagination =
        _txtPaginationCache[cacheKey] ??
        _paginateTxtSegment(segment: segment, viewport: _txtViewport!);
    _txtPaginationCache[cacheKey] = pagination;

    var pageIndex = 0;
    if (desiredPage != null) {
      pageIndex = _clampInt(
        desiredPage,
        0,
        math.max(0, pagination.pages.length - 1),
      );
    } else if (!resetToFirstPage) {
      if (preserveCharOffset != null) {
        pageIndex = _pageIndexForOffset(pagination, preserveCharOffset);
      } else {
        pageIndex = _clampInt(
          currentTxtPageIndex.value,
          0,
          math.max(0, pagination.pages.length - 1),
        );
      }
    }

    currentTxtPageIndex.value = pageIndex;
    txtPageCount.value = pagination.pages.length;
    txtPaginationReady.value = true;
    _refreshTxtPageController(initialPage: pageIndex);
  }

  _ReaderTxtPaginationResult _paginateTxtSegment({
    required ReaderTxtSegment segment,
    required Size viewport,
  }) {
    final text = segment.content;
    if (text.trim().isEmpty) {
      return _ReaderTxtPaginationResult(
        pages: const <ReaderTxtPage>[
          ReaderTxtPage(index: 0, start: 0, end: 0, text: ''),
        ],
        viewport: viewport,
      );
    }

    final availableWidth = math.max(
      1.0,
      viewport.width - txtPagePadding.horizontal,
    );
    final availableHeight = math.max(
      1.0,
      viewport.height - txtPagePadding.vertical,
    );
    final pages = <ReaderTxtPage>[];
    var start = 0;

    while (start < text.length) {
      var low = start + 1;
      var high = text.length;
      var best = low;

      while (low <= high) {
        final mid = low + ((high - low) ~/ 2);
        final candidate = text.substring(start, mid);
        if (_fitsTxtPage(
          text: candidate,
          maxWidth: availableWidth,
          maxHeight: availableHeight,
        )) {
          best = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }

      if (best <= start) {
        best = math.min(text.length, start + 1);
      }

      best = _refineTxtPageEnd(text, start, best);
      if (best <= start) {
        best = math.min(text.length, start + 1);
      }

      final pageText = text.substring(start, best).trimRight();
      pages.add(
        ReaderTxtPage(
          index: pages.length,
          start: start,
          end: best,
          text: pageText,
        ),
      );

      start = _nextTxtPageStart(text, best);
    }

    return _ReaderTxtPaginationResult(pages: pages, viewport: viewport);
  }

  bool _fitsTxtPage({
    required String text,
    required double maxWidth,
    required double maxHeight,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: txtTextStyle),
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: maxWidth);
    return painter.height <= maxHeight + 0.5;
  }

  int _refineTxtPageEnd(String text, int start, int candidate) {
    if (candidate >= text.length) {
      return text.length;
    }

    final windowStart = math.max(
      start + 1,
      candidate - _txtPaginationRefineWindow,
    );
    for (var index = candidate; index > windowStart; index--) {
      final char = text[index - 1];
      if (_txtRefineBreakChars.contains(char)) {
        return index;
      }
    }
    return candidate;
  }

  int _nextTxtPageStart(String text, int currentEnd) {
    var start = currentEnd;
    while (start < text.length) {
      final char = text[start];
      if (char != '\n' && char != '\r' && char != ' ' && char != '\t') {
        break;
      }
      start += 1;
    }
    return start;
  }

  int _pageIndexForOffset(_ReaderTxtPaginationResult pagination, int offset) {
    if (pagination.pages.isEmpty) return 0;

    for (final page in pagination.pages) {
      if (offset >= page.start && offset < page.end) {
        return page.index;
      }
    }

    if (offset >= pagination.pages.last.end) {
      return pagination.pages.last.index;
    }
    return 0;
  }

  int? get _currentTxtPageStartOffset {
    if (currentTxtPages.isEmpty) return null;
    final pageIndex = _clampInt(
      currentTxtPageIndex.value,
      0,
      math.max(0, currentTxtPages.length - 1),
    );
    return currentTxtPages[pageIndex].start;
  }

  _ReaderTxtPaginationResult? _paginationForSegment(int segmentIndex) {
    final viewport = _txtViewport;
    if (viewport == null) return null;
    return _txtPaginationCache[_txtPaginationCacheKey(
      segmentIndex: segmentIndex,
      viewport: viewport,
      fontSize: fontSize.value,
    )];
  }

  _ReaderTxtPaginationResult? get _currentTxtPagination {
    final segment = currentTxtSegment;
    final viewport = _txtViewport;
    if (segment == null || viewport == null) {
      return null;
    }
    return _txtPaginationCache[_txtPaginationCacheKey(
      segmentIndex: segment.index,
      viewport: viewport,
      fontSize: fontSize.value,
    )];
  }

  String _txtPaginationCacheKey({
    required int segmentIndex,
    required Size viewport,
    required double fontSize,
  }) {
    return [
      segmentIndex,
      viewport.width.round(),
      viewport.height.round(),
      fontSize.toStringAsFixed(2),
    ].join('|');
  }

  void _refreshTxtPageController({required int initialPage}) {
    _disposeTxtPageController();
    _txtPageController = PageController(initialPage: initialPage);
    txtPageControllerVersion.value += 1;
  }

  void _disposeTxtPageController() {
    _txtPageController?.dispose();
    _txtPageController = null;
    txtPageControllerVersion.value += 1;
  }

  Future<void> _updateFontSize(double nextValue) async {
    final normalized = nextValue.clamp(12.0, 30.0);
    if ((normalized - fontSize.value).abs() < 0.01) return;

    final preserveOffset = readerFormat.value == ReaderFileFormat.txt
        ? _currentTxtPageStartOffset
        : null;
    fontSize.value = normalized;
    await _preferences?.setDouble(_fontSizeStorageKey, normalized);

    switch (readerFormat.value) {
      case ReaderFileFormat.epub:
        await epubController.setFontSize(fontSize: normalized);
        return;
      case ReaderFileFormat.txt:
        _txtPaginationCache.clear();
        _rebuildCurrentTxtPagination(preserveCharOffset: preserveOffset);
        return;
      case ReaderFileFormat.pdf:
      case ReaderFileFormat.unknown:
        return;
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

  bool _hasUsableViewport(Size viewport) {
    return viewport.width.isFinite &&
        viewport.height.isFinite &&
        viewport.width > txtPagePadding.horizontal &&
        viewport.height > txtPagePadding.vertical;
  }

  bool _isSameViewport(Size left, Size right) {
    return (left.width - right.width).abs() < 1 &&
        (left.height - right.height).abs() < 1;
  }

  int _clampPdfPage(int pageNumber, int totalPages) {
    if (totalPages <= 0) {
      return math.max(1, pageNumber);
    }
    return _clampInt(pageNumber, 1, totalPages);
  }

  int _clampInt(int value, int minValue, int maxValue) {
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
  }

  Future<void> _disposeReaderResources() async {
    _persistTimer?.cancel();
    _chapterSyncTimer?.cancel();
    _persistTimer = null;
    _chapterSyncTimer = null;
    _persistToken += 1;
    _chapterSyncToken += 1;

    epubUrl.value = '';
    chapters.clear();
    chapterItems.clear();
    navigationItems.clear();
    txtSegments.clear();
    txtPaginationReady.value = false;
    txtPageCount.value = 0;
    currentTxtSegmentIndex.value = 0;
    currentTxtPageIndex.value = 0;
    currentChapterHref.value = '';
    currentCfi.value = '';
    currentPdfPage.value = 1;
    pdfPageCount.value = 0;
    _txtViewport = null;
    _txtPaginationCache.clear();
    _lastLocation = null;
    _restoreState = const ReaderRestoreState();
    _initialPdfPage = 1;
    displaySettings = null;

    _disposeTxtPageController();
    await _disposePdfResources();
  }

  Future<void> _disposePdfResources() async {
    final document = _pdfDocument;
    _pdfDocument = null;

    _pdfController?.dispose();
    _pdfController = null;

    if (document != null && !document.isClosed) {
      try {
        await document.close();
      } catch (_) {}
    }
  }

  @override
  void onClose() {
    _persistTimer?.cancel();
    _chapterSyncTimer?.cancel();
    _persistToken += 1;
    _chapterSyncToken += 1;
    unawaited(_persistReadingState(_persistToken));
    _disposeTxtPageController();
    unawaited(_disposePdfResources());
    super.onClose();
  }
}
