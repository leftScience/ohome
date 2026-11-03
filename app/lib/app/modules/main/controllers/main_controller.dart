import 'dart:async';

import 'package:get/get.dart';

import '../../home/controllers/home_controller.dart';
import '../../messages/controllers/messages_controller.dart';
import '../../quark_sync/controllers/quark_sync_controller.dart';
import '../../quark_transfer_tasks/controllers/quark_transfer_tasks_controller.dart';

class MainController extends GetxController {
  final index = 0.obs;
  final loadedIndexes = <int>{0}.obs;

  HomeController get _homeController => Get.find<HomeController>();
  MessagesController get _messagesController => Get.find<MessagesController>();

  void setIndex(int value) {
    final alreadyLoaded = loadedIndexes.contains(value);
    loadedIndexes.add(value);
    index.value = value;

    switch (value) {
      case 0:
        _homeController.refreshRecentHistory();
        unawaited(
          _messagesController.loadMessages(
            refresh: true,
            showErrorToast: false,
          ),
        );
        break;
      case 1:
        if (alreadyLoaded) {
          if (Get.isRegistered<QuarkTransferTasksController>()) {
            unawaited(Get.find<QuarkTransferTasksController>().refreshList());
          }
          if (Get.isRegistered<QuarkSyncController>()) {
            unawaited(Get.find<QuarkSyncController>().loadTasks(refresh: true));
          }
        }
        break;
    }
  }
}
