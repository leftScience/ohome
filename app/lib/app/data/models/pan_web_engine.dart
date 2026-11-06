import 'dart:convert';

/// 自定义网盘搜索源（第三方 Web 搜索）。
///
/// 配置存放在 sys_config 的 `quark_search_web_engines`，值为
/// `[{"name":"...","url":"https://example.com/search?q={kw}"}]`。
class PanWebEngine {
  const PanWebEngine({
    required this.id,
    required this.name,
    required this.urlTemplate,
  });

  final String id;
  final String name;
  final String urlTemplate;

  static const String defaultId = 'default';

  String buildSearchUrl(String keyword) {
    final encoded = Uri.encodeComponent(keyword.trim());
    final template = urlTemplate.trim();
    if (template.isEmpty) return '';
    if (template.contains('{kw}') || template.contains('{keyword}')) {
      return template
          .replaceAll('{kw}', encoded)
          .replaceAll('{keyword}', encoded);
    }
    return template;
  }

  static List<PanWebEngine> parseConfigValue(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return const <PanWebEngine>[];
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return const <PanWebEngine>[];
      final engines = <PanWebEngine>[];
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is! Map) continue;
        final map = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item);
        final name = (map['name'] ?? '').toString().trim();
        final url = (map['url'] ?? '').toString().trim();
        if (name.isEmpty || url.isEmpty) continue;
        engines.add(PanWebEngine(id: 'web_$i', name: name, urlTemplate: url));
      }
      return engines;
    } catch (_) {
      return const <PanWebEngine>[];
    }
  }

  static String serializeConfigValue(List<PanWebEngine> engines) {
    if (engines.isEmpty) return '';
    return jsonEncode(
      engines
          .map(
            (engine) => <String, String>{
              'name': engine.name.trim(),
              'url': engine.urlTemplate.trim(),
            },
          )
          .toList(growable: false),
    );
  }
}
