import 'package:get/get.dart';

import 'package:ohome/app/modules/home/controllers/home_controller.dart';
import 'package:ohome/app/modules/home/controllers/home_recommend_controller.dart';
import 'package:ohome/app/modules/me/controllers/me_controller.dart';
import 'package:ohome/app/modules/messages/controllers/messages_controller.dart';
import 'package:ohome/app/modules/quark_sync/controllers/quark_sync_controller.dart';
import 'package:ohome/app/modules/quark_transfer_tasks/controllers/quark_transfer_tasks_controller.dart';
import '../controllers/main_controller.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
    Get.put<MessagesController>(MessagesController());
    Get.put<HomeController>(HomeController());
    Get.lazyPut<HomeRecommendController>(() => HomeRecommendController());
    Get.put<MeController>(MeController());
    Get.lazyPut<QuarkTransferTasksController>(
      () => QuarkTransferTasksController(),
    );
    Get.lazyPut<QuarkSyncController>(() => QuarkSyncController());
  }
}
