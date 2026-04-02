import 'package:get/get.dart';
import 'package:ohome/app/data/api/app_message.dart';
import 'package:ohome/app/data/api/app_update.dart';
import 'package:ohome/app/data/api/auth.dart';
import 'package:ohome/app/data/api/config.dart';
import 'package:ohome/app/data/api/dict.dart';
import 'package:ohome/app/data/api/drops.dart';
import 'package:ohome/app/data/api/media_history.dart';
import 'package:ohome/app/data/api/quark.dart';
import 'package:ohome/app/data/api/quark_auto_save_task.dart';
import 'package:ohome/app/data/api/quark_tv_login.dart';
import 'package:ohome/app/data/api/quark_transfer_task.dart';
import 'package:ohome/app/data/api/server_update.dart';
import 'package:ohome/app/data/api/todo.dart';
import 'package:ohome/app/data/api/user.dart';
import 'package:ohome/app/data/storage/token_storage.dart';
import 'package:ohome/app/data/storage/user_storage.dart';
import 'package:ohome/app/services/app_update_service.dart';
import 'package:ohome/app/services/app_message_push_service.dart';
import 'package:ohome/app/services/android_pip_service.dart';
import 'package:ohome/app/services/auth_service.dart';
import 'package:ohome/app/services/history_playback_service.dart';
import 'package:ohome/app/services/media_history_service.dart';
import 'package:ohome/app/services/playback_entry_service.dart';
import 'package:ohome/app/services/video_cast_service.dart';
import 'package:ohome/app/utils/http_client.dart';

class IndexServices {
  static Future<void> init() async {
    final httpClient = HttpClient.instance;

    Get.put<WebdavApi>(WebdavApi(httpClient: httpClient), permanent: true);
    Get.put<AppMessageApi>(
      AppMessageApi(httpClient: httpClient),
      permanent: true,
    );
    Get.put<AppUpdateApi>(
      AppUpdateApi(httpClient: httpClient),
      permanent: true,
    );
    Get.put<ConfigApi>(ConfigApi(httpClient: httpClient), permanent: true);
    Get.put<DictApi>(DictApi(httpClient: httpClient), permanent: true);
    Get.put<DropsApi>(DropsApi(httpClient: httpClient), permanent: true);
    Get.put<TodoApi>(TodoApi(httpClient: httpClient), permanent: true);
    Get.put<QuarkAutoSaveTaskApi>(
      QuarkAutoSaveTaskApi(httpClient: httpClient),
      permanent: true,
    );
    Get.put<QuarkTvLoginApi>(
      QuarkTvLoginApi(httpClient: httpClient),
      permanent: true,
    );
    Get.put<QuarkTransferTaskApi>(
      QuarkTransferTaskApi(httpClient: httpClient),
      permanent: true,
    );
    Get.put<UserApi>(UserApi(httpClient: httpClient), permanent: true);
    Get.put<ServerUpdateApi>(
      ServerUpdateApi(httpClient: httpClient),
      permanent: true,
    );
    Get.put<MediaHistoryRepository>(
      MediaHistoryRepository(httpClient: httpClient),
      permanent: true,
    );

    final authService = Get.put<AuthService>(
      AuthService(
        tokenStorage: TokenStorage(),
        userStorage: UserStorage(),
        authApi: AuthApi(httpClient: httpClient),
        userApi: Get.find<UserApi>(),
      ),
      permanent: true,
    );
    Get.put<AppMessagePushService>(
      AppMessagePushService(authService: authService),
      permanent: true,
    );

    Get.put<MediaHistoryService>(
      MediaHistoryService(
        repository: Get.find<MediaHistoryRepository>(),
        authService: authService,
      ),
      permanent: true,
    );
    Get.put<VideoCastService>(VideoCastService(), permanent: true);
    Get.put<PlaybackEntryService>(PlaybackEntryService(), permanent: true);
    Get.put<HistoryPlaybackService>(HistoryPlaybackService(), permanent: true);
    Get.put<AppUpdateService>(
      AppUpdateService(appUpdateApi: Get.find<AppUpdateApi>()),
      permanent: true,
    );
    await Get.putAsync<AndroidPipService>(
      () => AndroidPipService().init(),
      permanent: true,
    );
    await authService.restoreSession();
  }
}
