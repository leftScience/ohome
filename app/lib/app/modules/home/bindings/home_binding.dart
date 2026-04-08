import 'package:get/get.dart';

import '../../messages/controllers/messages_controller.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MessagesController>()) {
      Get.put<MessagesController>(MessagesController());
    }
    if (!Get.isRegistered<HomeController>()) {
      Get.put<HomeController>(HomeController());
    }
  }
}
