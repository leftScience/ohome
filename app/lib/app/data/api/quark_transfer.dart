import '../../utils/http_client.dart';
import '../models/quark_share_preview_file.dart';
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

  Future<QuarkSharePreviewResult> sharePreview({
    required String shareUrl,
    String passcode = '',
    String pdirFid = '',
  }) {
    return _httpClient.post<QuarkSharePreviewResult>(
      'quarkAutoSaveTask/share-preview',
      showErrorToast: false,
      data: <String, dynamic>{
        'shareUrl': shareUrl.trim(),
        'passcode': passcode.trim(),
        'pdirFid': pdirFid.trim(),
      },
      decoder: (data) {
        if (data is! Map) {
          return const QuarkSharePreviewResult(files: [], pdirFid: '0');
        }
        return QuarkSharePreviewResult.fromJson(
          Map<String, dynamic>.from(data),
        );
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
