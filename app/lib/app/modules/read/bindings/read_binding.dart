import 'package:get/get.dart';

import '../controllers/read_controller.dart';

class ReadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReadController>(() => ReadController());
  }
}
