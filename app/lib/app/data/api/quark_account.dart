import '../../utils/http_client.dart';
import '../models/quark_account_status.dart';

class QuarkAccountApi {
  QuarkAccountApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<QuarkAccountStatus> getStatus({bool showErrorToast = true}) {
    return _httpClient.get<QuarkAccountStatus>(
      '/quarkAccount/status',
      showErrorToast: showErrorToast,
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return QuarkAccountStatus.fromJson(data);
        }
        if (data is Map) {
          return QuarkAccountStatus.fromJson(data.cast<String, dynamic>());
        }
        return QuarkAccountStatus.fallback;
      },
    );
  }

  Future<void> setSystemMode(String mode, {bool showErrorToast = true}) {
    return _httpClient.put<void>(
      '/quarkAccount/systemMode',
      data: <String, dynamic>{'mode': mode},
      showErrorToast: showErrorToast,
      decoder: (_) {},
    );
  }

  Future<void> setPreferExclusive(
    bool preferExclusive, {
    bool showErrorToast = true,
  }) {
    return _httpClient.put<void>(
      '/quarkAccount/preferExclusive',
      data: <String, dynamic>{'preferExclusive': preferExclusive},
      showErrorToast: showErrorToast,
      decoder: (_) {},
    );
  }
}
