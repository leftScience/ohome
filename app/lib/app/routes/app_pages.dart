// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';

import '../middlewares/auth_middleware.dart';
import '../middlewares/super_admin_middleware.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/messages/bindings/messages_binding.dart';
import '../modules/messages/views/messages_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/register/bindings/register_binding.dart';
import '../modules/register/views/register_view.dart';
import '../modules/main/bindings/main_binding.dart';
import '../modules/main/views/main_view.dart';
import '../modules/moments/bindings/moments_binding.dart';
import '../modules/moments/views/moments_view.dart';
import '../modules/plugin/bindings/plugin_binding.dart';
import '../modules/plugin/views/plugin_view.dart';
import '../modules/quark_login/bindings/quark_login_binding.dart';
import '../modules/quark_login/views/quark_login_view.dart';
import '../modules/quark_search_settings/bindings/quark_search_settings_binding.dart';
import '../modules/quark_search_settings/views/quark_search_settings_view.dart';
import '../modules/quark_stream_settings/bindings/quark_stream_settings_binding.dart';
import '../modules/quark_stream_settings/views/quark_stream_settings_view.dart';
import '../modules/quark_sync/bindings/quark_sync_binding.dart';
import '../modules/quark_sync/views/quark_sync_view.dart';
import '../modules/quark_transfer_tasks/bindings/quark_transfer_tasks_binding.dart';
import '../modules/quark_transfer_tasks/views/quark_transfer_tasks_view.dart';
import '../modules/search/bindings/search_binding.dart';
import '../modules/search/views/search_view.dart';
import '../modules/server_update/bindings/server_update_binding.dart';
import '../modules/server_update/views/server_update_view.dart';
import '../modules/user_management/bindings/user_management_binding.dart';
import '../modules/user_management/views/user_management_view.dart';
import '../modules/tv/bindings/tv_binding.dart';
import '../modules/tv/views/tv_view.dart';
import '../modules/player/bindings/player_binding.dart';
import '../modules/player/views/player_view.dart';
import '../modules/music/bindings/music_binding.dart';
import '../modules/music/views/music_view.dart';
import '../modules/music_player/bindings/music_player_binding.dart';
import '../modules/music_player/views/music_player_view.dart';
import '../modules/audiobook/bindings/audiobook_binding.dart';
import '../modules/audiobook/views/audiobook_view.dart';
import '../modules/history/bindings/history_binding.dart';
import '../modules/history/views/history_view.dart';
import '../modules/playlet/bindings/playlet_binding.dart';
import '../modules/playlet/views/playlet_view.dart';
import '../modules/playlet_player/bindings/playlet_player_binding.dart';
import '../modules/playlet_player/views/playlet_player_view.dart';
import '../modules/video_cast/views/video_cast_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.MAIN;

  static final routes = [
    GetPage(
      name: _Paths.MAIN,
      page: () => const MainView(),
      binding: MainBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.MESSAGES,
      page: () => const MessagesView(),
      binding: MessagesBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: '/MessagesView',
      page: () => const MessagesView(),
      binding: MessagesBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: _Paths.REGISTER,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: _Paths.MOMENTS,
      page: () => const MomentsView(),
      binding: MomentsBinding(),
    ),
    GetPage(
      name: _Paths.PLUGIN,
      page: () => const PluginView(),
      binding: PluginBinding(),
    ),
    GetPage(
      name: _Paths.QUARK_LOGIN,
      page: () => const QuarkLoginView(),
      binding: QuarkLoginBinding(),
      middlewares: [AuthMiddleware(), SuperAdminMiddleware()],
    ),
    GetPage(
      name: _Paths.QUARK_SEARCH_SETTINGS,
      page: () => const QuarkSearchSettingsView(),
      binding: QuarkSearchSettingsBinding(),
      middlewares: [AuthMiddleware(), SuperAdminMiddleware()],
    ),
    GetPage(
      name: _Paths.QUARK_STREAM_SETTINGS,
      page: () => const QuarkStreamSettingsView(),
      binding: QuarkStreamSettingsBinding(),
      middlewares: [AuthMiddleware(), SuperAdminMiddleware()],
    ),
    GetPage(
      name: _Paths.QUARK_SYNC,
      page: () => const QuarkSyncView(),
      binding: QuarkSyncBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.QUARK_TRANSFER_TASKS,
      page: () => const QuarkTransferTasksView(),
      binding: QuarkTransferTasksBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.USER_MANAGEMENT,
      page: () => const UserManagementView(),
      binding: UserManagementBinding(),
      middlewares: [AuthMiddleware(), SuperAdminMiddleware()],
    ),
    GetPage(
      name: _Paths.SERVER_UPDATE,
      page: () => const ServerUpdateView(),
      binding: ServerUpdateBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.SEARCH,
      page: () => const SearchView(),
      binding: SearchBinding(),
    ),
    GetPage(
      name: _Paths.TV,
      page: () => const TvView(),
      binding: TvBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.PLAYLET,
      page: () => const PlayletView(),
      binding: PlayLetBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.PLAYLET_PLAYER,
      page: () => const PlayletPlayerView(),
      binding: PlayletPlayerBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.VIDEO_CAST,
      page: () => const VideoCastView(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.PLAYER,
      page: () => const PlayerView(),
      binding: PlayerBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.MUSIC,
      page: () => MusicView(),
      binding: MusicBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.MUSIC_PLAYER,
      page: () => const MusicPlayerView(),
      binding: MusicPlayerBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.AUDIOBOOK,
      page: () => AudiobookView(),
      binding: AudiobookBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.HISTORY,
      page: () => const HistoryView(),
      binding: HistoryBinding(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
