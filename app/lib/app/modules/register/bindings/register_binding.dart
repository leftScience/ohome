import 'package:get/get.dart';
import 'package:ohome/app/data/storage/discovery_storage.dart';
import 'package:ohome/app/services/discovery_service.dart';

import '../controllers/register_controller.dart';

class RegisterBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DiscoveryService>()) {
      Get.put<DiscoveryService>(
        DiscoveryService(storage: DiscoveryStorage()),
        permanent: true,
      );
    }

    Get.lazyPut<RegisterController>(
      () => RegisterController(discoveryService: Get.find<DiscoveryService>()),
    );
  }
}
