import 'package:get/get.dart';

import '../controllers/share_preview_controller.dart';

class SharePreviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SharePreviewController>(() => SharePreviewController());
  }
}