import 'package:get/get.dart';

import '../controllers/messages_controller.dart';

class MessagesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MessagesController>()) {
      Get.put<MessagesController>(MessagesController());
    }
  }
}
