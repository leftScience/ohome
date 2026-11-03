import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/api/drops.dart';
import '../../../data/models/drops_event_model.dart';
import '../../../data/models/drops_item_model.dart';
import '../../../theme/app_theme.dart';
import '../controllers/drops_controller.dart';
import 'drops_item_detail_view.dart';
import 'drops_shared_widgets.dart';

enum DropsReminderType { expiringItems, upcomingEvents }

class DropsReminderView extends StatefulWidget {
  const DropsReminderView({super.key, required this.type});

  final DropsReminderType type;

  @override
  State<DropsReminderView> createState() => _DropsReminderViewState();
}

class _DropsReminderViewState extends State<DropsReminderView> {
  final DropsApi _dropsApi = Get.find<DropsApi>();

  bool _loading = true;
  List<DropsItemModel> _items = const <DropsItemModel>[];
  List<DropsEventModel> _events = const <DropsEventModel>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      if (widget.type == DropsReminderType.expiringItems) {
        final records = await _loadAllItems();
        final now = DateUtils.dateOnly(DateTime.now());
        final end = now.add(const Duration(days: 7));
        final filtered = records
            .where((item) {
              final expireAt = item.expireAt;
              if (!item.enabled || expireAt == null) return false;
              final date = DateUtils.dateOnly(expireAt);
              return !date.isBefore(now) && !date.isAfter(end);
            })
            .toList(growable: false);
        if (!mounted) return;
        setState(() {
          _items = filtered;
          _events = const <DropsEventModel>[];
        });
      } else {
        final now = DateUtils.dateOnly(DateTime.now());
        final records = await _loadAllEvents(month: now.month);
        final filtered = records
            .where((event) {
              final nextOccurAt = event.nextOccurAt;
              if (!event.enabled || nextOccurAt == null) return false;
              final date = DateUtils.dateOnly(nextOccurAt);
              return date.year == now.year && date.month == now.month;
            })
            .toList(growable: false);
        if (!mounted) return;
        setState(() {
          _events = filtered;
          _items = const <DropsItemModel>[];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<List<DropsItemModel>> _loadAllItems() async {
    const limit = 200;
    final records = <DropsItemModel>[];
    var page = 1;
    var total = 0;
    do {
      final result = await _dropsApi.getItemList(page: page, limit: limit);
      records.addAll(result.records);
      total = result.total;
      page += 1;
    } while (records.length < total);
    return records;
  }

  Future<List<DropsEventModel>> _loadAllEvents({required int month}) async {
    const limit = 200;
    final records = <DropsEventModel>[];
    var page = 1;
    var total = 0;
    do {
      final result = await _dropsApi.getEventList(
        month: month,
        page: page,
        limit: limit,
      );
      records.addAll(result.records);
      total = result.total;
      page += 1;
    } while (records.length < total);
    return records;
  }

  Future<void> _openItemDetail(DropsItemModel item) async {
    final id = item.id;
    if (id == null) return;
    await Get.find<DropsController>().ensureDictsLoaded();
    await Get.to<bool>(() => DropsItemDetailView(itemId: id));
    await Get.find<DropsController>().refreshOverview();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isItems = widget.type == DropsReminderType.expiringItems;
    final isEmpty = isItems ? _items.isEmpty : _events.isEmpty;
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: Text(isItems ? '临期提醒' : '临近提醒')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : isEmpty
            ? ListView(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                children: [
                  SizedBox(height: 120.h),
                  Center(
                    child: Text(
                      isItems ? '暂无临期物资' : '暂无临近日期',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                itemCount: isItems ? _items.length : _events.length,
                separatorBuilder: (_, _) => SizedBox(height: 12.h),
                itemBuilder: (_, index) {
                  if (isItems) {
                    final item = _items[index];
                    return DropsItemCard(
                      item: item,
                      onTap: () => _openItemDetail(item),
                    );
                  }
                  final event = _events[index];
                  return DropsEventCard(event: event);
                },
              ),
      ),
    );
  }
}
