class DoubanCategoryMapping {
  const DoubanCategoryMapping({required this.category, required this.type});

  final String category;
  final String type;

  factory DoubanCategoryMapping.fromJson(Map<String, dynamic> json) {
    return DoubanCategoryMapping(
      category: (json['category'] as String?)?.trim() ?? '',
      type: (json['type'] as String?)?.trim() ?? '',
    );
  }
}

class DoubanCategories {
  const DoubanCategories({
    required this.movie,
    required this.tv,
    this.playlet = const {},
    this.audiobook = const {},
  });

  final Map<String, Map<String, DoubanCategoryMapping>> movie;
  final Map<String, Map<String, DoubanCategoryMapping>> tv;
  final Map<String, Map<String, DoubanCategoryMapping>> playlet;
  final Map<String, Map<String, DoubanCategoryMapping>> audiobook;

  factory DoubanCategories.fromJson(Map<String, dynamic> json) {
    Map<String, Map<String, DoubanCategoryMapping>> decodeGroup(dynamic raw) {
      if (raw is! Map<String, dynamic>) return {};
      final out = <String, Map<String, DoubanCategoryMapping>>{};
      raw.forEach((groupKey, groupValue) {
        if (groupValue is! Map<String, dynamic>) return;
        final inner = <String, DoubanCategoryMapping>{};
        groupValue.forEach((subKey, subValue) {
          if (subValue is! Map<String, dynamic>) return;
          inner[subKey] = DoubanCategoryMapping.fromJson(subValue);
        });
        out[groupKey] = inner;
      });
      return out;
    }

    return DoubanCategories(
      movie: decodeGroup(json['movie']),
      tv: decodeGroup(json['tv']),
      playlet: decodeGroup(json['playlet']),
      audiobook: decodeGroup(json['audiobook']),
    );
  }
}

class DoubanRankingResponse {
  const DoubanRankingResponse({
    required this.records,
    required this.total,
    required this.category,
    required this.type,
  });

  final List<dynamic> records;
  final int total;
  final String category;
  final String type;

  factory DoubanRankingResponse.fromJson(Map<String, dynamic> json) {
    final records = json['records'];
    return DoubanRankingResponse(
      records: records is List ? records : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      category: (json['category'] as String?)?.trim() ?? '',
      type: (json['type'] as String?)?.trim() ?? '',
    );
  }
}
