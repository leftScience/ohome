import 'dart:convert';

import 'package:dio/dio.dart';

import '../../utils/backend_url_resolver.dart';
import '../../utils/http_client.dart';
import '../models/quark_file_entry.dart';

String normalizeQuarkConfigRootPath(String value) {
  var normalized = value.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) return '';

  final rawHadContent = normalized.isNotEmpty;
  normalized = normalized.replaceAll(RegExp(r'^/+|/+$'), '');
  final segments = normalized
      .split('/')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: true);

  if (segments.isNotEmpty && segments.first.toLowerCase() == 'quark') {
    segments.removeAt(0);
  }

  if (segments.isEmpty) {
    return rawHadContent ? '/' : '';
  }
  return segments.join('/');
}

class QuarkConfigOption {
  const QuarkConfigOption({
    required this.application,
    required this.rootPath,
    required this.remark,
  });

  final String application;
  final String rootPath;
  final String remark;

  factory QuarkConfigOption.fromJson(Map<String, dynamic> json) {
    return QuarkConfigOption(
      application: (json['application'] ?? '').toString().trim(),
      rootPath: normalizeQuarkConfigRootPath(
        (json['rootPath'] ?? '').toString(),
      ),
      remark: (json['remark'] ?? '').toString().trim(),
    );
  }
}

class WebdavApi {
  WebdavApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<List<QuarkConfigOption>> fetchMoveTargets() {
    return _httpClient.post<List<QuarkConfigOption>>(
      'quarkConfig/list',
      data: const <String, dynamic>{'page': 1, 'limit': 1000},
      decoder: (data) {
        if (data is! Map) {
          return const <QuarkConfigOption>[];
        }
        final records = data['records'];
        if (records is! List) {
          return const <QuarkConfigOption>[];
        }
        return records
            .whereType<Map>()
            .map((e) => QuarkConfigOption.fromJson(e.cast<String, dynamic>()))
            .where((e) => e.application.isNotEmpty && e.rootPath.isNotEmpty)
            .toList(growable: false);
      },
    );
  }

  Future<List<WebdavFileEntry>> fetchFileList({
    required String applicationType,
    required String path,
    int? page,
    int? size,
    String? sortType,
  }) {
    final app = applicationType.trim();
    final folder = path.trim().isEmpty ? '/' : path.trim();
    if (app.isEmpty) return Future.value(const <WebdavFileEntry>[]);

    final payload = <String, dynamic>{'path': folder};
    if (page != null && page > 0) {
      payload['page'] = page;
    }
    if (size != null && size > 0) {
      payload['size'] = size;
    }
    final normalizedSortType = sortType?.trim() ?? '';
    if (normalizedSortType.isNotEmpty) {
      payload['sortType'] = normalizedSortType;
    }

    return _httpClient.post<List<WebdavFileEntry>>(
      'quarkFs/$app/files/list',
      data: payload,
      decoder: (data) {
        if (data is! List) {
          throw ApiException('Invalid quark list response');
        }
        return data
            .whereType<Map>()
            .map((e) => WebdavFileEntry.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false);
      },
    );
  }

  Future<void> deleteEntry({
    required String applicationType,
    required String path,
  }) {
    final app = applicationType.trim();
    final targetPath = path.trim();
    if (app.isEmpty || targetPath.isEmpty) return Future.value();

    return _httpClient.delete<void>(
      'quarkFs/$app/files',
      data: <String, dynamic>{'path': targetPath},
      decoder: (_) {},
    );
  }

  Future<void> renameEntry({
    required String applicationType,
    required String path,
    required String newName,
  }) {
    final app = applicationType.trim();
    final targetPath = path.trim();
    final name = newName.trim();
    if (app.isEmpty || targetPath.isEmpty || name.isEmpty) {
      return Future.value();
    }

    return _httpClient.post<void>(
      'quarkFs/$app/files/rename',
      data: <String, dynamic>{'path': targetPath, 'newName': name},
      decoder: (_) {},
    );
  }

  Future<void> moveEntry({
    required String applicationType,
    required String path,
  }) {
    final app = applicationType.trim();
    final targetPath = path.trim();
    if (app.isEmpty || targetPath.isEmpty) {
      return Future.value();
    }

    return _httpClient.post<void>(
      'quarkFs/$app/files/move',
      data: <String, dynamic>{'path': targetPath},
      decoder: (_) {},
    );
  }

  Future<String> fetchTextFileContent({
    required String applicationType,
    required String path,
  }) async {
    final bytes = await fetchFileBytes(
      applicationType: applicationType,
      path: path,
    );
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<List<int>> fetchFileBytes({
    required String applicationType,
    required String path,
  }) {
    final app = applicationType.trim();
    final filePath = path.trim();
    if (app.isEmpty || filePath.isEmpty) {
      return Future.value(const <int>[]);
    }

    return _httpClient.get<List<int>>(
      'public/quarkFs/$app/files/stream',
      queryParameters: <String, dynamic>{'path': filePath},
      showErrorToast: false,
      options: Options(responseType: ResponseType.bytes),
      decoder: (data) {
        if (data is List<int>) return data;
        if (data is List) {
          return data.whereType<int>().toList(growable: false);
        }
        throw ApiException('文件内容解析失败');
      },
    );
  }

  String buildFileStreamUrl({
    required String applicationType,
    required String path,
  }) {
    final app = applicationType.trim();
    final filePath = path.trim();
    if (app.isEmpty || filePath.isEmpty) {
      return '';
    }

    final normalizedPath = filePath.startsWith('/') ? filePath : '/$filePath';
    final relative = Uri(
      path: 'public/quarkFs/$app/files/stream',
      queryParameters: <String, dynamic>{'path': normalizedPath},
    ).toString();
    return BackendUrlResolver.resolve(relative);
  }
}
