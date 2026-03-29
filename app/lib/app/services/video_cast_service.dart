import 'dart:convert';

import 'package:dlna_dart/dlna.dart';
import 'package:get/get.dart';

class VideoCastService extends GetxService {
  final RxBool isCasting = false.obs;
  final RxString currentDeviceName = ''.obs;
  final RxString currentDeviceKey = ''.obs;

  DLNADevice? _currentDevice;

  bool get hasActiveDevice => _currentDevice != null && isCasting.value;

  Future<bool> startCasting({
    required String deviceKey,
    required DLNADevice device,
    required String url,
    required String title,
    String sourcePath = '',
  }) async {
    try {
      final sameDevice = currentDeviceKey.value == deviceKey;
      if (!sameDevice) {
        try {
          await _currentDevice?.stop();
        } catch (_) {}
      }
      await _setDeviceMedia(
        device,
        url: url,
        title: title,
        sourcePath: sourcePath,
      );
      _currentDevice = device;
      currentDeviceKey.value = deviceKey;
      currentDeviceName.value = device.info.friendlyName;
      isCasting.value = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> castToCurrentDevice({
    required String url,
    required String title,
    String sourcePath = '',
  }) async {
    final device = _currentDevice;
    if (device == null || !isCasting.value) return false;
    try {
      await _setDeviceMedia(
        device,
        url: url,
        title: title,
        sourcePath: sourcePath,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopCasting() async {
    try {
      await _currentDevice?.stop();
    } catch (_) {}
    _currentDevice = null;
    currentDeviceKey.value = '';
    currentDeviceName.value = '';
    isCasting.value = false;
  }

  Future<Duration?> currentPosition() async {
    final device = _currentDevice;
    if (device == null || !isCasting.value) return null;
    try {
      final payload = await device.position();
      return _parsePosition(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setDeviceMedia(
    DLNADevice device, {
    required String url,
    required String title,
    required String sourcePath,
  }) async {
    await device.request(
      'SetAVTransportURI',
      utf8.encode(
        _buildSetAvTransportUriXml(
          url: url,
          title: title,
          protocolInfo: _protocolInfoFor(sourcePath, url),
          itemClass: _itemClassFor(sourcePath, url),
        ),
      ),
    );
    await device.play();
  }

  String _protocolInfoFor(String sourcePath, String url) {
    final mimeType = _mimeTypeFor(sourcePath, url);
    return 'http-get:*:$mimeType:DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000';
  }

  String _itemClassFor(String sourcePath, String url) {
    final mimeType = _mimeTypeFor(sourcePath, url);
    if (mimeType.startsWith('audio/')) {
      return 'object.item.audioItem.musicTrack';
    }
    if (mimeType.startsWith('image/')) {
      return 'object.item.imageItem.photo';
    }
    return 'object.item.videoItem';
  }

  String _mimeTypeFor(String sourcePath, String url) {
    final lookup = (sourcePath.isNotEmpty ? sourcePath : url).toLowerCase();
    if (lookup.endsWith('.mp4') || lookup.endsWith('.m4v')) {
      return 'video/mp4';
    }
    if (lookup.endsWith('.mkv')) {
      return 'video/x-matroska';
    }
    if (lookup.endsWith('.mov')) {
      return 'video/quicktime';
    }
    if (lookup.endsWith('.avi')) {
      return 'video/x-msvideo';
    }
    if (lookup.endsWith('.webm')) {
      return 'video/webm';
    }
    if (lookup.endsWith('.ts')) {
      return 'video/mp2t';
    }
    if (lookup.endsWith('.m2ts')) {
      return 'video/vnd.dlna.mpeg-tts';
    }
    return 'video/mp4';
  }

  String _buildSetAvTransportUriXml({
    required String url,
    required String title,
    required String protocolInfo,
    required String itemClass,
  }) {
    final safeUrl = const HtmlEscape(HtmlEscapeMode.element).convert(url);
    final safeTitle = const HtmlEscape(HtmlEscapeMode.element).convert(title);
    final safeProtocol = const HtmlEscape(
      HtmlEscapeMode.element,
    ).convert(protocolInfo);
    final metadata =
        '''
<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
  <item id="0" parentID="-1" restricted="1">
    <dc:title>$safeTitle</dc:title>
    <upnp:class>$itemClass</upnp:class>
    <res protocolInfo="$safeProtocol">$safeUrl</res>
  </item>
</DIDL-Lite>
''';
    final safeMetadata = const HtmlEscape(
      HtmlEscapeMode.element,
    ).convert(metadata);
    return '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <CurrentURI>$safeUrl</CurrentURI>
      <CurrentURIMetaData>$safeMetadata</CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>''';
  }

  Duration? _parsePosition(String payload) {
    final match = RegExp(r'<RelTime>([^<]+)</RelTime>').firstMatch(payload);
    final raw = match?.group(1)?.trim() ?? '';
    if (raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 3) return null;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final seconds = int.tryParse(parts[2]) ?? 0;
    if (hours < 0 || minutes < 0 || seconds < 0) return null;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }
}
