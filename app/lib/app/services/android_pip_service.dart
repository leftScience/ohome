import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class AndroidPipService extends GetxService {
  static const MethodChannel _channel = MethodChannel(
    'ohome/picture_in_picture',
  );

  bool? _supported;

  bool get isSupportedSync => _supported ?? false;

  Future<AndroidPipService> init() async {
    if (!GetPlatform.isAndroid || kIsWeb) {
      _supported = false;
      return this;
    }

    try {
      _supported =
          await _channel.invokeMethod<bool>('isPictureInPictureSupported') ??
          false;
    } catch (_) {
      _supported = false;
    }

    return this;
  }

  Future<bool> get isSupported async {
    final cached = _supported;
    if (cached != null) return cached;
    await init();
    return _supported ?? false;
  }

  Future<void> setEnabled({
    required bool enabled,
    double? aspectRatio,
    bool autoEnter = true,
  }) async {
    if (!await isSupported) return;
    try {
      await _channel.invokeMethod<void>('setPictureInPictureEnabled', {
        'enabled': enabled,
        'autoEnter': autoEnter,
        if (aspectRatio != null && aspectRatio.isFinite && aspectRatio > 0)
          'aspectRatio': aspectRatio,
      });
    } catch (_) {}
  }

  Future<bool> enterPictureInPicture({double? aspectRatio}) async {
    if (!await isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('enterPictureInPicture', {
            if (aspectRatio != null && aspectRatio.isFinite && aspectRatio > 0)
              'aspectRatio': aspectRatio,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
