import 'package:shared_preferences/shared_preferences.dart';

class AppEnvStorage {
  static const _kApiBaseUrlOverride = 'apiBaseUrlOverride';
  static const _kDefaultBackendNoticeDismissed =
      'defaultBackendNoticeDismissed';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    final cached = _prefs;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  Future<String?> readApiBaseUrlOverride() async {
    final prefs = await _instance();
    final value = prefs.getString(_kApiBaseUrlOverride);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> writeApiBaseUrlOverride(String value) async {
    final prefs = await _instance();
    await prefs.setString(_kApiBaseUrlOverride, value.trim());
  }

  Future<void> clearApiBaseUrlOverride() async {
    final prefs = await _instance();
    await prefs.remove(_kApiBaseUrlOverride);
  }

  Future<bool> readDefaultBackendNoticeDismissed() async {
    final prefs = await _instance();
    return prefs.getBool(_kDefaultBackendNoticeDismissed) ?? false;
  }

  Future<void> writeDefaultBackendNoticeDismissed(bool value) async {
    final prefs = await _instance();
    await prefs.setBool(_kDefaultBackendNoticeDismissed, value);
  }
}
