import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

import '../data/api/quark.dart';
import '../data/models/quark_file_entry.dart';
import '../modules/common/controllers/quark_folder_controller.dart';

const List<String> _kDefaultEntryBlacklist = <String>[''];

typedef ResourceEntryTap =
    Future<void> Function(
      WebdavFileEntry entry,
      List<WebdavFileEntry> entries,
      String currentPath,
    );

typedef ResourceAutoOpenPredicate =
    bool Function(List<WebdavFileEntry> entries, String currentPath);

typedef ResourceAutoOpenCallback =
    Future<void> Function(List<WebdavFileEntry> entries, String currentPath);
typedef ResourceEntriesReadyCallback =
    Future<void> Function(List<WebdavFileEntry> entries, String currentPath);

typedef ResourceIconBuilder = IconData Function(WebdavFileEntry entry);
typedef ResourceColorBuilder = Color Function(WebdavFileEntry entry);
typedef ResourceTextBuilder = String Function(WebdavFileEntry entry);

class ResourceCardPage extends StatefulWidget {
  const ResourceCardPage({
    super.key,
    required this.title,
    required this.controller,
    this.onFolderTap,
    this.onFileTap,
    this.iconBuilder,
    this.iconColorBuilder,
    this.subtitleBuilder,
    this.statusBuilder,
    this.shouldAutoOpen,
    this.onAutoOpen,
    this.onEntriesReady,
    this.emptyText = '暂无文件',
    this.blacklistedExtensions = _kDefaultEntryBlacklist,
    this.enableDelete = true,
    this.enableRename = true,
    this.enableMove = true,
  });

  final String title;
  final WebdavFolderController controller;
  final ResourceEntryTap? onFolderTap;
  final ResourceEntryTap? onFileTap;
  final ResourceIconBuilder? iconBuilder;
  final ResourceColorBuilder? iconColorBuilder;
  final ResourceTextBuilder? subtitleBuilder;
  final ResourceTextBuilder? statusBuilder;
  final ResourceAutoOpenPredicate? shouldAutoOpen;
  final ResourceAutoOpenCallback? onAutoOpen;
  final ResourceEntriesReadyCallback? onEntriesReady;
  final String emptyText;
  final List<String> blacklistedExtensions;
  final bool enableDelete;
  final bool enableRename;
  final bool enableMove;

  @override
  State<ResourceCardPage> createState() => _ResourceCardPageState();
}

class _ResourceCardPageState extends State<ResourceCardPage> {
  String? _autoOpeningPath;
  bool _autoOpening = false;
  String? _entriesReadyPath;
  bool _entriesReadyRunning = false;
  bool _loadMoreCheckScheduled = false;
  bool _cardActionsVisible = false;
  bool _renaming = false;
  bool _deletingSelected = false;
  bool _movingSelected = false;
  final Set<String> _selectedPaths = <String>{};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _loadMoreSentinelKey = GlobalKey();

  bool get _operationInProgress =>
      _renaming || _deletingSelected || _movingSelected;

  final ButtonStyle _appBarTextButtonStyle = TextButton.styleFrom(
    minimumSize: const Size(0, 32),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );
  late final ButtonStyle _renameActionButtonStyle = _buildAppBarActionStyle(
    const Color(0xFF64B5F6),
  );
  late final ButtonStyle _deleteActionButtonStyle = _buildAppBarActionStyle(
    const Color(0xFFE57373),
  );
  late final ButtonStyle _moveActionButtonStyle = _buildAppBarActionStyle(
    const Color(0xFF81C784),
  );

  ButtonStyle _buildAppBarActionStyle(Color color) {
    return _appBarTextButtonStyle.copyWith(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return color.withValues(alpha: 0.45);
        }
        return color;
      }),
    );
  }

  String _breakPath(String value) {
    if (value.isEmpty) return value;
    return value.replaceAll('/', '/\u200B').replaceAll('\\', '\\\u200B');
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    _tryLoadMoreFromSentinel();
  }

  void _tryLoadMoreFromSentinel() {
    if (!_scrollController.hasClients) return;
    if (widget.controller.loading.value ||
        widget.controller.loadingMore.value) {
      return;
    }
    if (!widget.controller.hasMore.value) return;
    final loadMoreError = widget.controller.loadMoreError.value?.trim() ?? '';
    if (loadMoreError.isNotEmpty) return;
    if (!_isLoadMoreSentinelVisible()) return;
    widget.controller.loadMoreCurrent();
  }

  bool _isLoadMoreSentinelVisible() {
    final sentinelContext = _loadMoreSentinelKey.currentContext;
    if (sentinelContext == null) return false;

    final renderObject = sentinelContext.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return false;
    }

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return false;

    final position = _scrollController.position;
    final revealTop = viewport.getOffsetToReveal(renderObject, 0).offset;
    final revealBottom = viewport.getOffsetToReveal(renderObject, 1).offset;
    final viewportStart = position.pixels;
    final viewportEnd = viewportStart + position.viewportDimension + 200;
    return revealTop <= viewportEnd && revealBottom >= viewportStart - 200;
  }

  void _scheduleLoadMoreIfNeeded({
    required bool hasMore,
    required bool loadingMore,
    required String loadMoreError,
  }) {
    if (!hasMore || loadingMore || loadMoreError.isNotEmpty) {
      _loadMoreCheckScheduled = false;
      return;
    }
    if (_loadMoreCheckScheduled) return;
    _loadMoreCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreCheckScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      _tryLoadMoreFromSentinel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final path = widget.controller.currentPath.value;
      final entries = widget.controller.entries.toList(growable: false);
      final loading = widget.controller.loading.value;
      final loadingMore = widget.controller.loadingMore.value;
      final hasMore = widget.controller.hasMore.value;
      final error = widget.controller.error.value;
      final loadMoreError = widget.controller.loadMoreError.value;
      final currentSort = widget.controller.currentSort.value;
      final selectedPaths = _visibleSelectedPaths(entries);
      final selectedCount = selectedPaths.length;
      final actionDisabled = loading || _operationInProgress;
      final idleCardActionsVisible = _cardActionsVisible;
      final sortDisabled = actionDisabled || loadingMore;

      return Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          leadingWidth: 40,
          automaticallyImplyLeading: !widget.controller.canGoBack,
          leading: widget.controller.canGoBack
              ? IconButton(
                  onPressed: widget.controller.popDir,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          actionsPadding: const EdgeInsets.only(right: 4),
          title: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: false,
          actions: [
            if (widget.enableRename && idleCardActionsVisible)
              TextButton(
                style: _renameActionButtonStyle,
                onPressed:
                    entries.isEmpty || actionDisabled || selectedCount != 1
                    ? null
                    : () => _renameSelectedEntry(entries),
                child: const Text('重命名'),
              ),
            if (widget.enableDelete && idleCardActionsVisible)
              TextButton(
                style: _deleteActionButtonStyle,
                onPressed:
                    entries.isEmpty || actionDisabled || selectedCount == 0
                    ? null
                    : _confirmDeleteSelected,
                child: const Text('删除'),
              ),
            if (widget.enableMove && idleCardActionsVisible)
              TextButton(
                style: _moveActionButtonStyle,
                onPressed:
                    entries.isEmpty || actionDisabled || selectedCount == 0
                    ? null
                    : _confirmMoveSelected,
                child: const Text('移动'),
              ),
            if (idleCardActionsVisible)
              IconButton(
                onPressed: actionDisabled ? null : _hideCardActions,
                icon: const Icon(Icons.close),
              )
            else if (!_cardActionsVisible)
              IconButton(
                onPressed: actionDisabled
                    ? null
                    : widget.controller.refreshCurrent,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: _buildBody(
          currentPath: path,
          entries: entries,
          loading: loading,
          loadingMore: loadingMore,
          hasMore: hasMore,
          error: error,
          loadMoreError: loadMoreError,
          currentSort: currentSort,
          sortDisabled: sortDisabled,
        ),
      );
    });
  }

  Widget _buildBody({
    required String currentPath,
    required List<WebdavFileEntry> entries,
    required bool loading,
    required bool loadingMore,
    required bool hasMore,
    required String? error,
    required String? loadMoreError,
    required WebdavListSortType currentSort,
    required bool sortDisabled,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final errText = error?.trim() ?? '';
    if (errText.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.controller.refreshCurrent,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (entries.isEmpty) {
      _resetAutoStatus(currentPath);
      _entriesReadyPath = null;
      return Center(
        child: Text(
          widget.emptyText,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    if (widget.onEntriesReady != null) {
      _scheduleEntriesReady(
        path: currentPath,
        entries: entries,
        callback: widget.onEntriesReady!,
      );
    } else {
      _resetEntriesReadyStatus(currentPath);
    }

    final shouldAutoOpen =
        widget.shouldAutoOpen != null &&
        widget.onAutoOpen != null &&
        widget.shouldAutoOpen!(entries, currentPath);
    if (shouldAutoOpen) {
      _scheduleAutoOpen(
        path: currentPath,
        entries: entries,
        callback: widget.onAutoOpen!,
      );
      return const Center(child: CircularProgressIndicator());
    }
    _resetAutoStatus(currentPath);

    final loadMoreErrText = loadMoreError?.trim() ?? '';
    _scheduleLoadMoreIfNeeded(
      hasMore: hasMore,
      loadingMore: loadingMore,
      loadMoreError: loadMoreErrText,
    );

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _buildSortToolbar(
            currentSort: currentSort,
            disabled: sortDisabled,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final selected = _isSelected(entry);
              return _buildEntryCard(
                entry: entry,
                entries: entries,
                currentPath: currentPath,
                selected: selected,
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: _buildLoadMoreSentinel(
            context: context,
            loadingMore: loadingMore,
            hasMore: hasMore,
            loadMoreError: loadMoreErrText,
          ),
        ),
      ],
    );
  }

  Widget _buildSortToolbar({
    required WebdavListSortType currentSort,
    required bool disabled,
  }) {
    final labelColor = disabled ? Colors.white38 : Colors.white70;
    final iconColor = disabled ? Colors.white30 : Colors.white54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF101113),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<WebdavListSortType>(
              enabled: !disabled,
              tooltip: '排序方式',
              padding: EdgeInsets.zero,
              color: const Color(0xFF1A1A1A),
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              itemBuilder: (context) => WebdavListSortType.values
                  .map(
                    (option) => PopupMenuItem<WebdavListSortType>(
                      value: option,
                      child: Text(
                        option.label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onSelected: (value) {
                if (value == currentSort) return;
                widget.controller.changeSort(value);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentSort.label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreSentinel({
    required BuildContext context,
    required bool loadingMore,
    required bool hasMore,
    required String loadMoreError,
  }) {
    final theme = Theme.of(context);
    Widget child;

    if (loadingMore) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (loadMoreError.isNotEmpty) {
      child = TextButton(
        onPressed: widget.controller.loadMoreCurrent,
        child: Text(
          '加载更多失败，点击重试',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    } else if (!hasMore) {
      child = const Text('没有更多了', style: TextStyle(color: Colors.white38));
    } else {
      child = const Text('继续下滑加载更多', style: TextStyle(color: Colors.white38));
    }

    return Container(
      key: _loadMoreSentinelKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      alignment: Alignment.center,
      child: child,
    );
  }

  void _hideCardActions() {
    if (!_cardActionsVisible && _selectedPaths.isEmpty) {
      return;
    }
    setState(() {
      _cardActionsVisible = false;
      _selectedPaths.clear();
    });
  }

  Set<String> _visibleSelectedPaths(List<WebdavFileEntry> entries) {
    if (_selectedPaths.isEmpty) return <String>{};
    final visiblePaths = entries
        .map((entry) => entry.path.trim())
        .where((path) => path.isNotEmpty)
        .toSet();
    return _selectedPaths.where(visiblePaths.contains).toSet();
  }

  bool _isSelected(WebdavFileEntry entry) {
    final path = entry.path.trim();
    if (path.isEmpty) return false;
    return _selectedPaths.contains(path);
  }

  void _toggleSelection(WebdavFileEntry entry) {
    if (_operationInProgress) return;
    final path = entry.path.trim();
    if (path.isEmpty) return;
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  Future<void> _renameSelectedEntry(List<WebdavFileEntry> entries) async {
    if (!widget.enableRename || _operationInProgress) return;

    final selectedEntries = entries
        .where((entry) => _selectedPaths.contains(entry.path.trim()))
        .toList(growable: false);
    if (selectedEntries.length != 1) {
      Get.snackbar('提示', '请先选择 1 项资源');
      return;
    }

    await _showRenameDialog(selectedEntries.single);
  }

  Future<void> _showRenameDialog(WebdavFileEntry entry) async {
    if (_operationInProgress || widget.controller.isDeletingPath(entry.path)) {
      return;
    }
    var draftName = entry.name;
    var renamed = false;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('重命名'),
          content: TextFormField(
            initialValue: entry.name,
            autofocus: true,
            decoration: const InputDecoration(labelText: '新名称'),
            onFieldSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            onChanged: (v) => draftName = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(draftName.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    final normalizedName = _normalizeRenameInput(newName, entry.name);
    if (normalizedName == null) return;

    setState(() {
      _renaming = true;
    });
    try {
      await widget.controller.renameEntry(
        path: entry.path,
        newName: normalizedName,
      );
      renamed = true;
      if (mounted) Get.snackbar('提示', '重命名成功');
    } catch (e) {
      if (mounted) Get.snackbar('错误', '重命名失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _renaming = false;
          if (renamed) {
            _cardActionsVisible = false;
            _selectedPaths.clear();
          }
        });
      }
    }
  }

  String? _normalizeRenameInput(String? value, String oldName) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('提示', '名称不能为空');
      return null;
    }
    if (trimmed == '.' || trimmed == '..') {
      Get.snackbar('提示', '名称不合法');
      return null;
    }
    if (RegExp(r'[\\/:*?"<>|]').hasMatch(trimmed)) {
      Get.snackbar('提示', '名称包含非法字符');
      return null;
    }
    if (trimmed == oldName.trim()) return null;
    return trimmed;
  }

  Future<void> _confirmDeleteSelected() async {
    if (_operationInProgress) return;

    final entries = widget.controller.entries.toList(growable: false);
    final selectedPaths = _visibleSelectedPaths(
      entries,
    ).toList(growable: false);
    if (selectedPaths.isEmpty) {
      Get.snackbar('提示', '请先选择要删除的资源');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('删除确认'),
          content: Text('确认删除已选中的 ${selectedPaths.length} 项资源吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() {
      _deletingSelected = true;
    });

    late final WebdavDeleteResult result;
    try {
      result = await widget.controller.deleteEntries(selectedPaths);
    } finally {
      if (mounted) {
        setState(() {
          _deletingSelected = false;
        });
      }
    }
    if (!mounted) return;

    if (result.successCount > 0) {
      Get.snackbar('提示', '已删除 ${result.successCount} 项');
    }
    if (result.failedCount > 0) {
      Get.snackbar('提示', '${result.failedCount} 项删除失败');
    }

    setState(() {
      _selectedPaths.removeAll(result.successPaths.map((path) => path.trim()));
      if (_selectedPaths.isEmpty) {
        _cardActionsVisible = false;
      }
    });
  }

  Future<void> _confirmMoveSelected() async {
    if (_operationInProgress) return;

    final entries = widget.controller.entries.toList(growable: false);
    final selectedPaths = _visibleSelectedPaths(
      entries,
    ).toList(growable: false);
    if (selectedPaths.isEmpty) {
      Get.snackbar('提示', '请先选择要移动的资源');
      return;
    }

    List<QuarkConfigOption> targets;
    try {
      targets = await widget.controller.fetchMoveTargets();
    } catch (e) {
      if (mounted) {
        Get.snackbar('错误', '获取移动目标失败: $e');
      }
      return;
    }
    if (targets.isEmpty) {
      Get.snackbar('提示', '未找到可用移动目标，请先配置 Quark rootPath');
      return;
    }

    final sourceConfig = _findMoveTarget(
      targets,
      widget.controller.applicationType,
    );
    if (sourceConfig == null || sourceConfig.rootPath.trim().isEmpty) {
      Get.snackbar('提示', '未找到当前应用的 rootPath 配置');
      return;
    }

    final selectedApplication = await _selectMoveTargetApplication(targets);
    if (selectedApplication == null || selectedApplication.isEmpty) return;
    if (_findMoveTarget(targets, selectedApplication) == null) {
      Get.snackbar('提示', '移动目标不存在');
      return;
    }

    setState(() {
      _movingSelected = true;
    });

    final absolutePaths = selectedPaths
        .map((p) => _buildMoveSourcePath(sourceConfig.rootPath, p))
        .toSet()
        .toList(growable: false);

    late final WebdavMoveResult result;
    try {
      result = await widget.controller.moveEntries(
        absolutePaths,
        targetApplicationType: selectedApplication,
      );
    } finally {
      if (mounted) {
        setState(() {
          _movingSelected = false;
        });
      }
    }
    if (!mounted) return;

    if (result.successCount > 0) {
      Get.snackbar('提示', '移动成功');
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await widget.controller.refreshCurrent();
      if (!mounted) return;
      setState(() {
        _selectedPaths.clear();
      });
      return;
    }

    if (result.failedCount > 0) {
      Get.snackbar('提示', '${result.failedCount} 项移动失败');
    }
  }

  Future<String?> _selectMoveTargetApplication(
    List<QuarkConfigOption> targets,
  ) async {
    var selected = widget.controller.applicationType.trim();
    if (targets.every((t) => t.application != selected)) {
      selected = targets.first.application;
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('选择移动目标'),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() {
                        selected = value;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: targets
                          .map((target) {
                            final app = target.application;
                            final sub = target.rootPath.trim();
                            final label = target.remark.trim();
                            return RadioListTile<String>(
                              value: app,
                              title: Text(label.isEmpty ? app : label),
                              subtitle: sub.isEmpty ? null : Text(sub),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(selected),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  QuarkConfigOption? _findMoveTarget(
    List<QuarkConfigOption> targets,
    String application,
  ) {
    final app = application.trim();
    if (app.isEmpty) return null;
    for (final t in targets) {
      if (t.application == app) return t;
    }
    return null;
  }

  String _buildMoveSourcePath(String rootPath, String sourcePath) {
    String normalize(String input) {
      final raw = input.trim().replaceAll('\\', '/');
      final parts = raw
          .split('/')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      if (parts.isEmpty) return '/';
      return '/${parts.join('/')}';
    }

    final root = normalize(rootPath);
    final source = normalize(sourcePath);
    if (source == '/') return root;
    if (root == '/') return source;

    final rootTrimmed = root.startsWith('/') ? root.substring(1) : root;
    final sourceTrimmed = source.startsWith('/') ? source.substring(1) : source;
    if (sourceTrimmed == rootTrimmed ||
        sourceTrimmed.startsWith('$rootTrimmed/')) {
      return source;
    }
    return '/$rootTrimmed/$sourceTrimmed';
  }

  void _scheduleAutoOpen({
    required String path,
    required List<WebdavFileEntry> entries,
    required ResourceAutoOpenCallback callback,
  }) {
    if (_autoOpening || _autoOpeningPath == path) return;
    _autoOpening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await callback(entries, path);
      } finally {
        _autoOpeningPath = path;
        _autoOpening = false;
      }
    });
  }

  void _resetAutoStatus(String path) {
    if (_autoOpeningPath != path) {
      _autoOpeningPath = null;
    }
  }

  void _scheduleEntriesReady({
    required String path,
    required List<WebdavFileEntry> entries,
    required ResourceEntriesReadyCallback callback,
  }) {
    if (_entriesReadyRunning || _entriesReadyPath == path) {
      return;
    }
    _entriesReadyRunning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await callback(entries, path);
      } finally {
        _entriesReadyPath = path;
        _entriesReadyRunning = false;
      }
    });
  }

  void _resetEntriesReadyStatus(String path) {
    if (_entriesReadyRunning) {
      return;
    }
    if (_entriesReadyPath != path) {
      _entriesReadyPath = null;
    }
  }

  Widget _buildEntryCard({
    required WebdavFileEntry entry,
    required List<WebdavFileEntry> entries,
    required String currentPath,
    required bool selected,
  }) {
    final subtitleBuilder = widget.subtitleBuilder ?? _defaultSubtitle;
    final statusBuilder = widget.statusBuilder ?? _defaultStatus;
    final iconBuilder = widget.iconBuilder ?? _defaultIcon;
    final iconColorBuilder = widget.iconColorBuilder ?? _defaultIconColor;

    final subtitle = subtitleBuilder(entry).trim();
    final blocked = _isBlacklisted(entry);
    final deleting = widget.controller.isDeletingPath(entry.path);
    final status = blocked && !entry.isDir
        ? '不支持的文件类型'
        : statusBuilder(entry).trim();
    final displayStatus = deleting ? '删除中...' : status;
    final highlightColor = Theme.of(context).colorScheme.primary;
    final deletingColor = Theme.of(context).colorScheme.error;
    final selectionActive = _cardActionsVisible;
    final borderColor = deleting
        ? deletingColor.withValues(alpha: 0.9)
        : (selected ? highlightColor : Colors.white.withValues(alpha: 0.08));
    final borderWidth = deleting || selected ? 1.4 : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: deleting
              ? null
              : () async {
                  if (selectionActive) {
                    _toggleSelection(entry);
                    return;
                  }
                  if (blocked || _operationInProgress) return;
                  if (_cardActionsVisible) {
                    _hideCardActions();
                  }
                  await _handleTap(entry, entries, currentPath);
                },
          onLongPress:
              deleting ||
                  (!widget.enableRename &&
                      !widget.enableDelete &&
                      !widget.enableMove) ||
                  _operationInProgress
              ? null
              : () {
                  if (selectionActive) {
                    _toggleSelection(entry);
                    return;
                  }
                  final path = entry.path.trim();
                  if (path.isEmpty) return;
                  setState(() {
                    _cardActionsVisible = true;
                    _selectedPaths
                      ..clear()
                      ..add(path);
                  });
                },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      iconBuilder(entry),
                      color: iconColorBuilder(entry),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _breakPath(entry.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selectionActive)
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: selected ? highlightColor : Colors.white54,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 2),
                Text(
                  displayStatus,
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    WebdavFileEntry entry,
    List<WebdavFileEntry> entries,
    String currentPath,
  ) async {
    if (entry.isDir) {
      if (widget.onFolderTap != null) {
        await widget.onFolderTap!(entry, entries, currentPath);
      } else {
        await widget.controller.enterDir(entry);
      }
      return;
    }

    if (widget.onFileTap != null) {
      await widget.onFileTap!(entry, entries, currentPath);
    }
  }

  IconData _defaultIcon(WebdavFileEntry entry) {
    return entry.isDir ? Icons.folder_rounded : Icons.insert_drive_file;
  }

  Color _defaultIconColor(WebdavFileEntry entry) {
    return entry.isDir ? Colors.amber : Colors.lightBlue;
  }

  String _defaultSubtitle(WebdavFileEntry entry) {
    final info = <String>[];
    if (!entry.isDir) {
      final size = _formatBytes(entry.size);
      if (size.isNotEmpty) info.add(size);
    }
    final updated = _formatUpdatedAt(entry.updatedAt);
    if (updated.isNotEmpty) info.add(updated);
    return info.join('  ');
  }

  String _defaultStatus(WebdavFileEntry entry) {
    return entry.isDir ? '文件夹' : '点击播放';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final fixed = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
    return '${size.toStringAsFixed(fixed)}${units[unit]}';
  }

  String _formatUpdatedAt(int seconds) {
    if (seconds <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  bool _isBlacklisted(WebdavFileEntry entry) {
    if (entry.isDir) return false;
    final name = entry.name.toLowerCase().trim();
    if (name.isEmpty || widget.blacklistedExtensions.isEmpty) return false;
    for (final ext in widget.blacklistedExtensions) {
      final normalized = ext.toLowerCase().trim();
      if (normalized.isEmpty) continue;
      if (name.endsWith(normalized)) return true;
    }
    return false;
  }
}
