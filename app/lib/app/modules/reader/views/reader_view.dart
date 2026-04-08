import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:get/get.dart';

import '../controllers/reader_controller.dart';

class ReaderView extends GetView<ReaderController> {
  const ReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        backgroundColor: controller.activeTheme.backgroundColor,
        appBar: AppBar(
          title: Text(controller.title.value),
          actions: [
            IconButton(
              tooltip: '主题',
              onPressed: controller.canOpenBook
                  ? () => _showThemeSheet(context)
                  : null,
              icon: const Icon(Icons.palette_outlined),
            ),
            IconButton(
              tooltip: '减小字号',
              onPressed: controller.canOpenBook
                  ? controller.decreaseFontSize
                  : null,
              icon: const Icon(Icons.text_decrease_rounded),
            ),
            IconButton(
              tooltip: '增大字号',
              onPressed: controller.canOpenBook
                  ? controller.increaseFontSize
                  : null,
              icon: const Icon(Icons.text_increase_rounded),
            ),
            IconButton(
              tooltip: '目录',
              onPressed: controller.chapters.isEmpty
                  ? null
                  : () => _showChapterSheet(context),
              icon: const Icon(Icons.list_alt_rounded),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
                style: TextStyle(
                  color: controller.activeTheme.secondaryTextColor,
                  height: 1.6,
                ),
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
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Future<void> _showChapterSheet(BuildContext context) {
    const itemExtent = 56.0;
    final currentIndex = controller.currentChapterIndex;
    final initialOffset = currentIndex >= 0 ? currentIndex * itemExtent : 0.0;
    final scrollController = ScrollController(initialScrollOffset: initialOffset);

    void scrollToCurrentChapter() {
      final index = controller.currentChapterIndex;
      if (index < 0 || !scrollController.hasClients) return;
      scrollController.animateTo(
        index * itemExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: controller.activeTheme.surfaceColor,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.currentChapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: controller.activeTheme.secondaryTextColor,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: controller.currentChapterIndex >= 0
                          ? scrollToCurrentChapter
                          : null,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('定位当前'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: controller.activeTheme.dividerColor),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemExtent: itemExtent,
                  itemCount: controller.chapterItems.length,
                  itemBuilder: (context, index) {
                    final item = controller.chapterItems[index];
                    final chapter = item.chapter;
                    final isCurrent = index == controller.currentChapterIndex;
                    final title = chapter.title.trim().isEmpty
                        ? '第 ${index + 1} 章'
                        : chapter.title.trim();

                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: controller.activeTheme.dividerColor,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.only(
                          left: 16 + item.depth * 18,
                          right: 12,
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent
                                ? controller.activeTheme.accentColor
                                : controller.activeTheme.textColor,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(
                                Icons.play_arrow_rounded,
                                color: controller.activeTheme.accentColor,
                              )
                            : Icon(
                                Icons.chevron_right_rounded,
                                color: controller.activeTheme.secondaryTextColor,
                              ),
                        onTap: () => controller.openChapter(chapter),
                      ),
                    );
                  },
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
                    border: Border.all(color: theme.textColor.withValues(alpha: 0.18)),
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
