import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/api/quark.dart';
import '../../../data/api/quark_auto_save_task.dart';
import '../../../data/models/quark_auto_save_task_model.dart';
import '../../../data/models/quark_auto_save_task_upsert_payload.dart';
import '../../../theme/app_theme.dart';
import '../models/quark_sync_form_draft.dart';

class QuarkSyncFormView extends StatefulWidget {
  const QuarkSyncFormView({super.key, this.initialTask, this.initialDraft});

  final QuarkAutoSaveTaskModel? initialTask;
  final QuarkSyncFormDraft? initialDraft;

  @override
  State<QuarkSyncFormView> createState() => _QuarkSyncFormViewState();
}

class _QuarkSyncFormViewState extends State<QuarkSyncFormView> {
  static const Map<int, String> _weekLabels = <int, String>{
    1: '周一',
    2: '周二',
    3: '周三',
    4: '周四',
    5: '周五',
    6: '周六',
    7: '周日',
  };

  final _formKey = GlobalKey<FormState>();
  final QuarkAutoSaveTaskApi _taskApi = Get.find<QuarkAutoSaveTaskApi>();
  final WebdavApi _webdavApi = Get.find<WebdavApi>();

  late final TextEditingController _taskNameController;
  late final TextEditingController _shareUrlController;
  late final TextEditingController _runTimeController;

  List<_SavePathOption> _savePathOptions = const <_SavePathOption>[];
  String? _selectedApplication;
  String _scheduleType = 'daily';
  final Set<int> _runWeekDays = <int>{1};
  bool _enabled = true;
  bool _loadingPaths = false;
  bool _submitting = false;
  bool _showWeekError = false;

  bool get _isEdit => widget.initialTask != null;

  String get _selectedSavePath {
    for (final option in _savePathOptions) {
      if (option.application == _selectedApplication) {
        return option.savePath;
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    final draft = widget.initialDraft;
    _taskNameController = TextEditingController(
      text: task?.taskName ?? draft?.taskName ?? '',
    );
    _shareUrlController = TextEditingController(
      text: task?.shareUrl ?? draft?.shareUrl ?? '',
    );
    _scheduleType = task?.scheduleType == 'weekly' ? 'weekly' : 'daily';
    _enabled = task?.enabled ?? true;
    final draftApplication = draft?.application?.trim() ?? '';
    _selectedApplication = draftApplication.isEmpty ? null : draftApplication;
    _runTimeController = TextEditingController(
      text: task?.runTime.isNotEmpty == true ? task!.runTime : '03:00',
    );
    if (task != null && task.runWeekDays.isNotEmpty) {
      _runWeekDays
        ..clear()
        ..addAll(task.runWeekDays);
    }
    _loadSavePathOptions();
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _shareUrlController.dispose();
    _runTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: Text(_isEdit ? '编辑任务' : '新增任务')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
            children: [
              _buildIntroCard(),
              SizedBox(height: 16.h),
              _buildFormCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: SizedBox(
          height: 52.h,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.primary,
              disabledBackgroundColor: AppThemeColors.primary.withValues(
                alpha: 0.45,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEdit ? '保存修改' : '创建任务',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppThemeColors.textOnAccent,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  color: Color(0xFF43A047),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEdit ? '修改自动转存任务' : '创建自动转存任务',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(
            label: '任务名称',
            child: TextFormField(
              controller: _taskNameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入任务名称';
                }
                return null;
              },
              decoration: _inputDecoration('请输入任务名称'),
            ),
          ),
          SizedBox(height: 16.h),
          _buildField(
            label: '分享链接',
            child: TextFormField(
              controller: _shareUrlController,
              minLines: 3,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入分享链接';
                }
                return null;
              },
              decoration: _inputDecoration('请输入夸克分享链接'),
            ),
          ),
          SizedBox(height: 16.h),
          _buildField(
            label: '保存路径',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedApplication ?? '__empty__'),
                  initialValue: _selectedApplication,
                  items: _savePathOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.application,
                          child: Text(
                            option.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  validator: (value) {
                    if (_loadingPaths) {
                      return '正在加载保存路径';
                    }
                    if (value == null || value.isEmpty) {
                      return '请选择保存路径';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedApplication = value;
                    });
                  },
                  decoration: _inputDecoration(
                    _loadingPaths ? '正在加载保存路径' : '请选择保存路径',
                    suffixIcon: IconButton(
                      onPressed: _loadingPaths ? null : _loadSavePathOptions,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                  dropdownColor: AppThemeColors.surface,
                  isExpanded: true,
                  iconEnabledColor: AppThemeColors.textMuted,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppThemeColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _selectedSavePath.isEmpty
                      ? '保存路径来自夸克目录配置；如果列表为空，请先在系统里配置夸克目录。'
                      : '实际保存路径：$_selectedSavePath',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppThemeColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _buildField(
            label: '同步规则',
            child: Row(
              children: [
                Expanded(
                  child: _ScheduleTypeCard(
                    label: '每天',
                    selected: _scheduleType == 'daily',
                    onTap: () {
                      setState(() {
                        _scheduleType = 'daily';
                        _showWeekError = false;
                      });
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _ScheduleTypeCard(
                    label: '每周',
                    selected: _scheduleType == 'weekly',
                    onTap: () {
                      setState(() {
                        _scheduleType = 'weekly';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _buildField(
            label: '执行时间',
            child: TextFormField(
              controller: _runTimeController,
              readOnly: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请选择执行时间';
                }
                return null;
              },
              onTap: _pickRunTime,
              decoration: _inputDecoration(
                '请选择执行时间',
                suffixIcon: const Icon(Icons.access_time_rounded),
              ),
            ),
          ),
          if (_scheduleType == 'weekly') ...[
            SizedBox(height: 16.h),
            _buildField(
              label: '周几',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: _weekLabels.entries
                        .map((entry) {
                          final selected = _runWeekDays.contains(entry.key);
                          return FilterChip(
                            label: Text(entry.value),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _runWeekDays.add(entry.key);
                                } else {
                                  _runWeekDays.remove(entry.key);
                                }
                                _showWeekError = false;
                              });
                            },
                            selectedColor: AppThemeColors.primary.withValues(
                              alpha: 0.18,
                            ),
                            checkmarkColor: AppThemeColors.primary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppThemeColors.primary
                                  : AppThemeColors.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            backgroundColor: AppThemeColors.surfaceMuted,
                            side: BorderSide(
                              color: selected
                                  ? AppThemeColors.primary.withValues(
                                      alpha: 0.65,
                                    )
                                  : AppThemeColors.border,
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                  if (_showWeekError) ...[
                    SizedBox(height: 8.h),
                    Text(
                      '每周规则至少选择一天',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppThemeColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SizedBox(height: 16.h),
          _buildField(
            label: '是否启用',
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppThemeColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppThemeColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _enabled ? '启用任务' : '停用任务',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppThemeColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _enabled ? '保存后任务会按调度规则自动执行' : '保存后任务不会进入自动调度',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppThemeColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    onChanged: (value) {
                      setState(() {
                        _enabled = value;
                      });
                    },
                    activeThumbColor: AppThemeColors.primary,
                    activeTrackColor: AppThemeColors.primary.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppThemeColors.textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13.sp, color: AppThemeColors.textDisabled),
      filled: true,
      fillColor: AppThemeColors.surfaceMuted,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppThemeColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppThemeColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppThemeColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppThemeColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppThemeColors.danger),
      ),
    );
  }

  Future<void> _loadSavePathOptions() async {
    setState(() {
      _loadingPaths = true;
    });

    try {
      final configs = await _webdavApi.fetchMoveTargets();
      final options = configs
          .map(_SavePathOption.fromConfig)
          .where((item) => item.savePath.isNotEmpty)
          .toList(growable: false);
      final currentPath = _normalizeSavePath(
        widget.initialTask?.savePath ?? widget.initialDraft?.savePath ?? '',
      );

      final existsCurrent =
          currentPath.isNotEmpty &&
          options.any((item) => item.savePath == currentPath);
      final merged = <_SavePathOption>[
        ...options,
        if (!existsCurrent && currentPath.isNotEmpty)
          _SavePathOption(
            application: '__current__',
            label: '当前路径',
            savePath: currentPath,
          ),
      ];

      String? selectedApplication = _selectedApplication;
      final hasSelected =
          selectedApplication != null &&
          merged.any((item) => item.application == selectedApplication);
      if (!hasSelected) {
        selectedApplication = null;
        for (final item in merged) {
          if (item.savePath == currentPath) {
            selectedApplication = item.application;
            break;
          }
        }
      }
      if (selectedApplication == null && merged.isNotEmpty) {
        selectedApplication = merged.first.application;
      }

      if (!mounted) return;
      setState(() {
        _savePathOptions = merged;
        _selectedApplication = selectedApplication;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savePathOptions = const <_SavePathOption>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPaths = false;
        });
      }
    }
  }

  Future<void> _pickRunTime() async {
    FocusScope.of(context).unfocus();
    final current =
        _parseTime(_runTimeController.text) ??
        const TimeOfDay(hour: 3, minute: 0);
    final result = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppThemeColors.primary),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (result == null) return;

    _runTimeController.text =
        '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_scheduleType == 'weekly' && _runWeekDays.isEmpty) {
      setState(() {
        _showWeekError = true;
      });
      return;
    }

    final payload = QuarkAutoSaveTaskUpsertPayload(
      id: widget.initialTask?.id,
      taskName: _taskNameController.text,
      shareUrl: _shareUrlController.text,
      savePath: _selectedSavePath,
      scheduleType: _scheduleType,
      runTime: _runTimeController.text,
      runWeek: _scheduleType == 'weekly'
          ? (_runWeekDays.toList()..sort()).join(',')
          : '',
      enabled: _enabled,
    );

    setState(() {
      _submitting = true;
    });

    try {
      await _taskApi.addOrUpdateTask(payload);
      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar('提示', _isEdit ? '任务已更新' : '任务已创建');
    } catch (_) {
      return;
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  static TimeOfDay? _parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _normalizeSavePath(String path) {
    final text = path.trim().replaceAll('\\', '/');
    return text.replaceAll(RegExp(r'^/+|/+$'), '');
  }
}

class _ScheduleTypeCard extends StatelessWidget {
  const _ScheduleTypeCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppThemeColors.primary.withValues(alpha: 0.15)
          : AppThemeColors.surfaceMuted,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Ink(
          height: 48.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected
                  ? AppThemeColors.primary.withValues(alpha: 0.6)
                  : AppThemeColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppThemeColors.primary
                    : AppThemeColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavePathOption {
  const _SavePathOption({
    required this.application,
    required this.label,
    required this.savePath,
  });

  final String application;
  final String label;
  final String savePath;

  factory _SavePathOption.fromConfig(QuarkConfigOption config) {
    final label = config.remark.isNotEmpty ? config.remark : config.application;
    return _SavePathOption(
      application: config.application,
      label: label,
      savePath: _QuarkSyncFormViewState._normalizeSavePath(config.rootPath),
    );
  }
}
