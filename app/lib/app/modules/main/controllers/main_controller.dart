import 'dart:async';

import 'package:get/get.dart';

import '../../drops/controllers/drops_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../messages/controllers/messages_controller.dart';

class MainController extends GetxController {
  final index = 0.obs;
  final loadedIndexes = <int>{0}.obs;

  HomeController get _homeController => Get.find<HomeController>();
  MessagesController get _messagesController => Get.find<MessagesController>();
  DropsController get _dropsController => Get.find<DropsController>();

  void setIndex(int value) {
    final wasLoaded = loadedIndexes.contains(value);
    loadedIndexes.add(value);
    index.value = value;
    if (value == 0) {
      _homeController.refreshRecentHistory();
      unawaited(
        _messagesController.loadMessages(refresh: true, showErrorToast: false),
      );
    } else if (value == 1 && wasLoaded) {
      _dropsController.refreshOverview();
    }
  }
}
