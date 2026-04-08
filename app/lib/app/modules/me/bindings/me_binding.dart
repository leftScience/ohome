import 'package:get/get.dart';

import '../controllers/me_controller.dart';

class MeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MeController>()) {
      Get.put<MeController>(MeController());
    }
  }
}
