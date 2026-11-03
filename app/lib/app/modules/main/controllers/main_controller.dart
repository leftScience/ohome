import 'dart:async';

import 'package:get/get.dart';

import '../../home/controllers/home_controller.dart';
import '../../messages/controllers/messages_controller.dart';

class MainController extends GetxController {
  final index = 0.obs;
  final loadedIndexes = <int>{0}.obs;

  HomeController get _homeController => Get.find<HomeController>();
  MessagesController get _messagesController => Get.find<MessagesController>();

  void setIndex(int value) {
    loadedIndexes.add(value);
    index.value = value;
    if (value == 0) {
      _homeController.refreshRecentHistory();
      unawaited(
        _messagesController.loadMessages(refresh: true, showErrorToast: false),
      );
    }
  }
}
