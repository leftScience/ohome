import 'package:get/get.dart';

import 'package:ohome/app/modules/drops/controllers/drops_controller.dart';
import 'package:ohome/app/modules/home/controllers/home_controller.dart';
import 'package:ohome/app/modules/me/controllers/me_controller.dart';
import 'package:ohome/app/modules/messages/controllers/messages_controller.dart';
import '../controllers/main_controller.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
    Get.put<MessagesController>(MessagesController());
    Get.put<HomeController>(HomeController());
    Get.put<DropsController>(DropsController());
    Get.put<MeController>(MeController());
  }
}
