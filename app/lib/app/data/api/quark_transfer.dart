import '../../utils/http_client.dart';
import 'quark.dart' show normalizeQuarkConfigRootPath;

class QuarkTransferRepository {
  QuarkTransferRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<String> getQuarkRootPath(String application) {
    return _httpClient.get<String>(
      'quarkConfig/$application',
      decoder: (data) {
        if (data is! Map) return '';
        final rootPath = data['rootPath'];
        return rootPath is String ? normalizeQuarkConfigRootPath(rootPath) : '';
      },
    );
  }

  Future<void> transferOnce({
    required String shareUrl,
    required String savePath,
    required String application,
    required String resourceName,
    String passcode = '',
  }) {
    return _httpClient
        .post<dynamic>(
          'quarkAutoSaveTask/transfer',
          showErrorToast: false,
          data: <String, dynamic>{
            'shareUrl': shareUrl.trim(),
            'savePath': savePath.trim(),
            'passcode': passcode.trim(),
            'application': application.trim(),
            'resourceName': resourceName.trim(),
          },
        )
        .then((_) {});
  }
}
