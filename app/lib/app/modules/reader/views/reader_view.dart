import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:get/get.dart';
import 'package:pdfx/pdfx.dart';

import '../controllers/reader_controller.dart';

class ReaderView extends GetView<ReaderController> {
  const ReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chrome = _ReaderChromeColors.resolve(controller);
      final isPdf = controller.readerFormat.value == ReaderFileFormat.pdf;
      return Scaffold(
        backgroundColor: chrome.backgroundColor,
        appBar: AppBar(
          backgroundColor: isPdf ? Colors.black : chrome.surfaceColor,
          foregroundColor: isPdf ? Colors.white : chrome.textColor,
          title: Text(controller.title.value),
          actions: [
            if (controller.canSelectTheme)
              IconButton(
                tooltip: '主题',
                onPressed: () => _showThemeSheet(context),
                icon: const Icon(Icons.palette_outlined),
              ),
            if (controller.canAdjustFontSize) ...[
              IconButton(
                tooltip: '减小字号',
                onPressed: controller.decreaseFontSize,
                icon: const Icon(Icons.text_decrease_rounded),
              ),
              IconButton(
                tooltip: '增大字号',
                onPressed: controller.increaseFontSize,
                icon: const Icon(Icons.text_increase_rounded),
              ),
            ],
            IconButton(
              tooltip: controller.navigationTooltip,
              onPressed: controller.canShowNavigation
                  ? () => _showNavigationSheet(context)
                  : null,
              icon: const Icon(Icons.list_alt_rounded),
            ),
          ],
        ),
        body: _buildBody(),
      );
    });
  }

  Widget _buildBody() {
    final chrome = _ReaderChromeColors.resolve(controller);
    if (controller.loading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = controller.error.value.trim();
    if (error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: chrome.secondaryTextColor, height: 1.6),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.retry,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    switch (controller.readerFormat.value) {
      case ReaderFileFormat.epub:
        return _buildEpubBody();
      case ReaderFileFormat.txt:
        return _TxtReaderBody(controller: controller);
      case ReaderFileFormat.pdf:
        return _PdfReaderBody(controller: controller);
      case ReaderFileFormat.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEpubBody() {
    return Stack(
      children: [
        Positioned.fill(
          child: EpubViewer(
            epubController: controller.epubController,
            epubSource: EpubSource.fromUrl(controller.epubUrl.value),
            initialCfi: controller.initialCfi,
            displaySettings: controller.displaySettings,
            onEpubLoaded: controller.onEpubLoaded,
            onChaptersLoaded: controller.onChaptersLoaded,
            onRelocated: controller.onRelocated,
          ),
        ),
        if (controller.viewerLoading.value)
          Positioned.fill(
            child: ColoredBox(
              color: controller.activeTheme.overlayColor,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Future<void> _showNavigationSheet(BuildContext context) {
    final chrome = _ReaderChromeColors.resolve(controller);
    final isPdf = controller.readerFormat.value == ReaderFileFormat.pdf;
    final standardDrawerAccent = Theme.of(context).colorScheme.primary;
    final sheetSurfaceColor = isPdf
        ? const Color(0xFF141414)
        : chrome.surfaceColor;
    final sheetTextColor = isPdf ? Colors.white : chrome.textColor;
    final sheetSecondaryTextColor = isPdf
        ? Colors.white60
        : chrome.secondaryTextColor;
    final sheetAccentColor = isPdf
        ? standardDrawerAccent
        : chrome.accentColor;
    final sheetDividerColor = isPdf
        ? Colors.white.withValues(alpha: 0.08)
        : chrome.dividerColor;
    const itemExtent = 56.0;
    final currentIndex = controller.currentNavigationIndex;
    final initialOffset = currentIndex >= 0 ? currentIndex * itemExtent : 0.0;
    final scrollController = ScrollController(
      initialScrollOffset: initialOffset,
    );

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetSurfaceColor,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Text(
                      controller.navigationTooltip,
                      style: TextStyle(
                        color: sheetTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: sheetDividerColor),
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    controller: scrollController,
                    itemExtent: itemExtent,
                    itemCount: controller.navigationItems.length,
                    itemBuilder: (context, index) {
                      final item = controller.navigationItems[index];
                      final selected =
                          index == controller.currentNavigationIndex;

                      return Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? sheetAccentColor.withValues(alpha: 0.14)
                              : isPdf
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.transparent,
                          borderRadius: isPdf
                              ? BorderRadius.circular(10)
                              : BorderRadius.zero,
                          border: Border(
                            bottom: BorderSide(color: sheetDividerColor),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.only(
                            left: 16 + item.depth * 18,
                            right: 12,
                          ),
                          title: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? sheetAccentColor
                                  : sheetTextColor,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: Icon(
                            selected
                                ? isPdf
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_checked_rounded
                                : Icons.chevron_right_rounded,
                            color: selected
                                ? sheetAccentColor
                                : isPdf
                                ? Colors.white38
                                : sheetSecondaryTextColor,
                          ),
                          onTap: () async {
                            await controller.openNavigationItem(item);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showThemeSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: controller.activeTheme.surfaceColor,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: ReaderController.themePresets.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: controller.activeTheme.dividerColor),
            itemBuilder: (context, index) {
              final theme = ReaderController.themePresets[index];
              final selected = theme.id == controller.selectedThemeId.value;
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.textColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: theme.textColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  theme.label,
                  style: TextStyle(color: controller.activeTheme.textColor),
                ),
                trailing: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: controller.activeTheme.accentColor,
                      )
                    : null,
                onTap: () async {
                  await controller.applyTheme(theme.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _TxtReaderBody extends StatefulWidget {
  const _TxtReaderBody({required this.controller});

  final ReaderController controller;

  @override
  State<_TxtReaderBody> createState() => _TxtReaderBodyState();
}

class _TxtReaderBodyState extends State<_TxtReaderBody> {
  Size? _lastViewport;
  bool _handlingBoundaryTurn = false;

  bool _handleTxtScrollNotification(ScrollNotification notification) {
    if (notification is! OverscrollNotification ||
        notification.metrics.axis != Axis.horizontal ||
        _handlingBoundaryTurn) {
      return false;
    }

    final pages = widget.controller.currentTxtPages;
    if (pages.isEmpty) return false;

    final currentPageIndex = widget.controller.currentTxtPageIndex.value;
    final atFirstPage = currentPageIndex <= 0;
    final atLastPage = currentPageIndex >= pages.length - 1;

    if (notification.overscroll > 0 && atLastPage) {
      unawaited(_turnTxtBoundaryPage(forward: true));
    } else if (notification.overscroll < 0 && atFirstPage) {
      unawaited(_turnTxtBoundaryPage(forward: false));
    }

    return false;
  }

  Future<void> _turnTxtBoundaryPage({required bool forward}) async {
    if (_handlingBoundaryTurn) return;
    _handlingBoundaryTurn = true;
    try {
      if (forward) {
        await widget.controller.goNextPage();
      } else {
        await widget.controller.goPreviousPage();
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
    } finally {
      _handlingBoundaryTurn = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastViewport == null ||
            (_lastViewport!.width - viewport.width).abs() >= 1 ||
            (_lastViewport!.height - viewport.height).abs() >= 1) {
          _lastViewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.controller.updateTxtViewport(viewport);
          });
        }

        return Obx(() {
          final currentSegment = widget.controller.currentTxtSegment;
          if (currentSegment == null) {
            return _ReaderPlaceholder(
              text: '没有可显示的文本内容',
              color: widget.controller.activeTheme.secondaryTextColor,
            );
          }
          if (!widget.controller.txtPaginationReady.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final pages = widget.controller.currentTxtPages;
          final pageController = widget.controller.txtPageController;
          final version = widget.controller.txtPageControllerVersion.value;

          if (currentSegment.content.trim().isEmpty) {
            return _ReaderPlaceholder(
              text: '文本内容为空',
              color: widget.controller.activeTheme.secondaryTextColor,
            );
          }
          if (pageController == null || pages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleTxtScrollNotification,
                  child: PageView.builder(
                    key: ValueKey(
                      'txt-$version-${widget.controller.currentTxtSegmentIndex.value}',
                    ),
                    controller: pageController,
                    itemCount: pages.length,
                    onPageChanged: widget.controller.onTxtPageChanged,
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return Padding(
                        padding: ReaderController.txtPagePadding,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            page.text,
                            style: widget.controller.txtTextStyle,
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _ReaderBadge(
                  backgroundColor: widget.controller.activeTheme.surfaceColor
                      .withValues(alpha: 0.86),
                  borderColor: widget.controller.activeTheme.dividerColor,
                  textColor: widget.controller.activeTheme.secondaryTextColor,
                  text:
                      '第 ${widget.controller.currentTxtSegmentIndex.value + 1}/${widget.controller.txtSegments.length} 片 · '
                      '第 ${widget.controller.currentTxtPageIndex.value + 1}/${widget.controller.txtPageCount.value} 页',
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

class _PdfReaderBody extends StatelessWidget {
  const _PdfReaderBody({required this.controller});

  final ReaderController controller;

  @override
  Widget build(BuildContext context) {
    final pdfController = controller.pdfController;
    final chrome = _ReaderChromeColors.resolve(controller);
    const badgeBackgroundColor = Color(0xE6111827);
    const badgeBorderColor = Color(0xFF374151);
    const badgeTextColor = Color(0xFFE5E7EB);
    if (pdfController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: PdfView(
            controller: pdfController,
            renderer: _renderPdfPage,
            scrollDirection: Axis.horizontal,
            backgroundDecoration: const BoxDecoration(color: Colors.white),
            onDocumentLoaded: controller.onPdfDocumentLoaded,
            onDocumentError: controller.onPdfDocumentError,
            onPageChanged: controller.onPdfPageChanged,
            builders: const PdfViewBuilders<DefaultBuilderOptions>(
              options: DefaultBuilderOptions(),
              documentLoaderBuilder: _emptyBuilder,
              pageLoaderBuilder: _emptyBuilder,
              errorBuilder: _errorBuilder,
            ),
          ),
        ),
        if (controller.viewerLoading.value)
          Positioned.fill(
            child: ColoredBox(
              color: chrome.overlayColor,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Obx(
            () => _ReaderBadge(
              backgroundColor: badgeBackgroundColor,
              borderColor: badgeBorderColor,
              textColor: badgeTextColor,
              text: controller.pdfPageCount.value > 0
                  ? '第 ${controller.currentPdfPage.value}/${controller.pdfPageCount.value} 页'
                  : '加载页码中...',
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderBadge extends StatelessWidget {
  const _ReaderBadge({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.text,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ReaderPlaceholder extends StatelessWidget {
  const _ReaderPlaceholder({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: TextStyle(color: color, fontSize: 14)),
    );
  }
}

Widget _emptyBuilder(BuildContext context) => const SizedBox.shrink();

Widget _errorBuilder(BuildContext context, Exception error) =>
    const SizedBox.shrink();

const _pdfFallbackRenderWidth = 1440.0;
const _pdfFallbackRenderHeight = 2048.0;
const _pdfFallbackAspectRatio = 1 / 1.41421356237;
const _pdfMaxRenderDimension = 2048.0;

Future<PdfPageImage?> _renderPdfPage(PdfPage page) {
  final renderSize = _resolvePdfRenderSize(page);
  return page.render(
    width: renderSize.width,
    height: renderSize.height,
    format: PdfPageImageFormat.jpeg,
    backgroundColor: '#ffffff',
  );
}

Size _resolvePdfRenderSize(PdfPage page) {
  final rawWidth = page.width;
  final rawHeight = page.height;
  final hasValidWidth = _isUsablePdfDimension(rawWidth);
  final hasValidHeight = _isUsablePdfDimension(rawHeight);

  double width = _pdfFallbackRenderWidth;
  double height = _pdfFallbackRenderHeight;

  if (hasValidWidth && hasValidHeight) {
    final desiredWidth = rawWidth * 2;
    final desiredHeight = rawHeight * 2;
    final longestSide = math.max(desiredWidth, desiredHeight);
    final scale = longestSide > _pdfMaxRenderDimension
        ? _pdfMaxRenderDimension / longestSide
        : 1.0;
    width = math.max(1.0, desiredWidth * scale);
    height = math.max(1.0, desiredHeight * scale);
  } else if (hasValidWidth) {
    width = math.min(rawWidth * 2, _pdfMaxRenderDimension);
    height = math.max(1.0, width / _pdfFallbackAspectRatio);
  } else if (hasValidHeight) {
    height = math.min(rawHeight * 2, _pdfMaxRenderDimension);
    width = math.max(1.0, height * _pdfFallbackAspectRatio);
  }

  if (!width.isFinite || width <= 0) {
    width = _pdfFallbackRenderWidth;
  }
  if (!height.isFinite || height <= 0) {
    height = _pdfFallbackRenderHeight;
  }
  return Size(width, height);
}

bool _isUsablePdfDimension(double value) => value.isFinite && value > 1;

class _ReaderChromeColors {
  const _ReaderChromeColors({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.overlayColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.dividerColor,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final Color overlayColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color dividerColor;

  static const _pdf = _ReaderChromeColors(
    backgroundColor: Color(0xFFF3F4F6),
    surfaceColor: Colors.white,
    overlayColor: Color(0xCCFFFFFF),
    textColor: Color(0xFF111827),
    secondaryTextColor: Color(0xFF6B7280),
    accentColor: Color(0xFF2563EB),
    dividerColor: Color(0xFFE5E7EB),
  );

  factory _ReaderChromeColors.resolve(ReaderController controller) {
    if (controller.readerFormat.value == ReaderFileFormat.pdf) {
      return _pdf;
    }

    final theme = controller.activeTheme;
    return _ReaderChromeColors(
      backgroundColor: theme.backgroundColor,
      surfaceColor: theme.surfaceColor,
      overlayColor: theme.overlayColor,
      textColor: theme.textColor,
      secondaryTextColor: theme.secondaryTextColor,
      accentColor: theme.accentColor,
      dividerColor: theme.dividerColor,
    );
  }
}
