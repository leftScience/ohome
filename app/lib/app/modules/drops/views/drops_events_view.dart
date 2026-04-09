import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_floating_action_button_position.dart';
import '../controllers/drops_events_controller.dart';
import 'drops_shared_widgets.dart';

class DropsEventsView extends GetView<DropsEventsController> {
  const DropsEventsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重要日期')),
      floatingActionButtonLocation:
          AppFloatingActionButtonPosition.scaffoldLocation,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.openCreate,
        backgroundColor: AppThemeColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增日期'),
      ),
      body: DropsEventsPanel(
        controller: controller,
        filterPadding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
        listPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 120.h),
      ),
    );
  }
}
