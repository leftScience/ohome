import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/reader_controller.dart';

class ReaderView extends GetView<ReaderController> {
  const ReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        appBar: AppBar(title: Text(controller.title.value)),
        body: _buildBody(),
      );
    });
  }

  Widget _buildBody() {
    if (controller.loading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final err = controller.error.value.trim();
    if (err.isNotEmpty && controller.content.value.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                err,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: controller.loadContent,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        child: SelectableText(
          controller.content.value,
          style: const TextStyle(
            height: 1.8,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
