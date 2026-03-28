import 'package:get/get.dart';

import '../controllers/server_update_controller.dart';

class ServerUpdateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ServerUpdateController>(() => ServerUpdateController());
  }
}
