import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_floating_action_button_position.dart';
import '../controllers/drops_items_controller.dart';
import 'drops_shared_widgets.dart';

class DropsItemsView extends GetView<DropsItemsController> {
  const DropsItemsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('物资管理')),
      floatingActionButtonLocation:
          AppFloatingActionButtonPosition.scaffoldLocation,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.openCreate,
        backgroundColor: AppThemeColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('新增物资'),
      ),
      body: DropsItemsPanel(
        controller: controller,
        filterPadding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
        listPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 120.h),
      ),
    );
  }
}
