class PansouResourceTextParts {
  const PansouResourceTextParts({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  factory PansouResourceTextParts.parse({
    required String note,
    String fallbackUrl = '',
  }) {
    final value = note.trim();
    if (value.isEmpty) {
      return PansouResourceTextParts(
        title: fallbackUrl.trim(),
        description: '',
      );
    }

    const descriptionMarkers = <String>[
      '描述：',
      '描述:',
      '【描述】',
      '简介：',
      '简介:',
      '亮点：',
      '亮点:',
    ];

    var splitIndex = value.length;
    var descriptionPart = '';
    for (final marker in descriptionMarkers) {
      final index = value.indexOf(marker);
      if (index >= 0 && index < splitIndex) {
        splitIndex = index;
        descriptionPart = value.substring(index).trim();
      }
    }

    final title = _normalizeResourceText(
      value.substring(0, splitIndex).trim(),
      fallbackUrl.trim(),
      stripPattern: RegExp(r'^(?:名称|片名|标题|资源名|资源名称)\s*[：:]?\s*'),
    );
    final description = _normalizeResourceText(
      descriptionPart,
      '',
      stripPattern: RegExp(r'^(?:【描述】|描述|简介|亮点)\s*[：:]?\s*'),
    );

    return PansouResourceTextParts(title: title, description: description);
  }

  static String _normalizeResourceText(
    String value,
    String fallback, {
    RegExp? stripPattern,
  }) {
    if (value.trim().isEmpty) return fallback.trim();

    final lines = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !_looksLikeUrl(line))
        .toList(growable: false);

    var merged = lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (stripPattern != null) {
      merged = merged.replaceFirst(stripPattern, '').trim();
    }

    if (merged.isNotEmpty) return merged;
    return fallback.trim();
  }

  static bool _looksLikeUrl(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }
}

class PansouResourceItem {
  PansouResourceItem({
    required this.url,
    required this.note,
    required this.source,
    required this.datetime,
    required this.images,
    required this.type,
  });

  final String url;
  final String note;
  final String source;
  final String datetime;
  final List<String> images;
  final String type;

  PansouResourceTextParts get textParts =>
      PansouResourceTextParts.parse(note: note, fallbackUrl: url);

  String get transferTitle =>
      PansouResourceTextParts.parse(note: note).title.trim();

  String get dateYmd {
    final value = datetime.trim();
    if (value.isEmpty) return '';
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  String get dateCnYmd {
    final raw = datetime.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('0001-01-01') || raw.contains('0001-01-01')) return '';
    if (raw.startsWith('0000-00-00') || raw.contains('0000-00-00')) return '';

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    if (digits.length == 8) {
      final y = digits.substring(0, 4);
      final m = digits.substring(4, 6);
      final d = digits.substring(6, 8);
      return '$y年$m月$d日';
    }

    if (digits.length == 14) {
      final y = int.tryParse(digits.substring(0, 4));
      final m = int.tryParse(digits.substring(4, 6));
      final d = int.tryParse(digits.substring(6, 8));
      if (y == null || m == null || d == null) return '';
      final dt = DateTime(y, m, d);
      if (dt.year <= 1) return '';
      return _formatCn(dt);
    }

    if (digits.length == 10 || digits.length == 13) {
      final value = int.tryParse(digits);
      final millis = value == null
          ? null
          : (digits.length == 13 ? value : value * 1000);
      if (millis != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(millis);
        if (dt.year <= 1) return '';
        return _formatCn(dt);
      }
    }

    final head = raw.length >= 10 ? raw.substring(0, 10) : raw;
    final match = RegExp(
      r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})',
    ).firstMatch(head);
    if (match != null) {
      final y = match.group(1) ?? '';
      final m = (match.group(2) ?? '').padLeft(2, '0');
      final d = (match.group(3) ?? '').padLeft(2, '0');
      if (y.isNotEmpty && m.isNotEmpty && d.isNotEmpty) {
        return '$y年$m月$d日';
      }
    }

    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed != null) {
      if (parsed.year <= 1) return '';
      return _formatCn(parsed);
    }

    return head;
  }

  static String _formatCn(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y年$m月$d日';
  }

  factory PansouResourceItem.fromJson(
    Map<String, dynamic> json, {
    required String type,
  }) {
    final images = json['images'];
    return PansouResourceItem(
      url: (json['url'] as String?)?.trim() ?? '',
      note: (json['note'] as String?)?.trim() ?? '',
      source: (json['source'] as String?)?.trim() ?? '',
      datetime: (json['datetime'] as String?)?.trim() ?? '',
      images: images is List
          ? images
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      type: type,
    );
  }

  bool get isEmpty => url.isEmpty && note.isEmpty;
}
