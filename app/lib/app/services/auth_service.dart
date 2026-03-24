import 'package:get/get.dart';
import 'package:ohome/app/data/api/auth.dart';
import 'package:ohome/app/data/models/login_result.dart';
import 'package:ohome/app/data/models/register_status.dart';
import 'package:ohome/app/data/models/token_pair.dart';
import 'package:ohome/app/data/models/user_model.dart';
import 'package:ohome/app/data/api/user.dart';
import 'package:ohome/app/data/storage/token_storage.dart';
import 'package:ohome/app/data/storage/user_storage.dart';
import 'package:ohome/app/modules/music_player/controllers/music_player_controller.dart';
import 'package:ohome/app/modules/player/controllers/player_controller.dart';

class AuthService extends GetxService {
  AuthService({
    required TokenStorage tokenStorage,
    required UserStorage userStorage,
    required AuthApi authApi,
    required UserApi userApi,
  }) : _tokenStorage = tokenStorage,
       _userStorage = userStorage,
       _authApi = authApi,
       _userApi = userApi;

  final TokenStorage _tokenStorage;
  final UserStorage _userStorage;
  final AuthApi _authApi;
  final UserApi _userApi;

  final accessToken = RxnString();
  final refreshToken = RxnString();
  final user = Rxn<UserModel>();

  Future<void>? _refreshingFuture; // 加个字段避免重复刷新

  bool get isLoggedIn {
    final token = accessToken.value;
    return token != null && token.trim().isNotEmpty;
  }

  // 重新读取用户信息
  Future<void> restoreSession() async {
    accessToken.value = await _tokenStorage.readAccessToken();
    refreshToken.value = await _tokenStorage.readRefreshToken();
    user.value = await _userStorage.readUser();
    if (isLoggedIn) {
      await _syncProfileSilently();
    }
  }

  Future<void> login({required String name, required String password}) async {
    final LoginResult res = await _authApi.login(
      name: name,
      password: password,
    );
    // 存储token
    await _applyTokens(
      TokenPair(accessToken: res.accessToken, refreshToken: res.refreshToken),
    );
    // 存储用户信息
    await _applyUser(res.user);
  }

  Future<void> register({required String name, required String password}) {
    return _authApi.register(name: name, password: password);
  }

  Future<RegisterStatus> getRegisterStatus() {
    return _authApi.getRegisterStatus();
  }

  // 刷新token
  Future<void> refreshTokenSingleflight() {
    final future = _refreshingFuture;
    if (future != null) return future;

    final created = _doRefresh().whenComplete(() {
      _refreshingFuture = null;
    });
    _refreshingFuture = created;
    return created;
  }

  Future<void> _doRefresh() async {
    final rt = refreshToken.value ?? await _tokenStorage.readRefreshToken();
    if (rt == null || rt.trim().isEmpty) {
      throw Exception('缺少 refreshToken');
    }
    final res = await _authApi.refreshToken(refreshToken: rt);
    await _applyTokens(res);
  }

  Future<void> _applyTokens(TokenPair pair) async {
    accessToken.value = pair.accessToken;
    refreshToken.value = pair.refreshToken;
    await _tokenStorage.writeAccessToken(pair.accessToken);
    await _tokenStorage.writeRefreshToken(pair.refreshToken);
  }

  Future<void> _applyUser(UserModel value) async {
    user.value = value;
    await _userStorage.writeUser(value);
  }

  Future<void> saveUser(UserModel value) {
    return _applyUser(value);
  }

  Future<UserModel> refreshProfile() async {
    final profile = await _userApi.getProfile();
    await _applyUser(profile);
    return profile;
  }

  Future<void> _syncProfileSilently() async {
    try {
      await refreshProfile();
    } catch (_) {
      return;
    }
  }

  Future<void> logout() async {
    await _stopActiveMediaPlayback();
    accessToken.value = null;
    refreshToken.value = null;
    user.value = null;
    await _tokenStorage.clear();
    await _userStorage.clear();
  }

  Future<void> _stopActiveMediaPlayback() async {
    if (Get.isRegistered<MusicPlayerController>()) {
      await Get.find<MusicPlayerController>().clearPlaybackSession();
    }
    if (Get.isRegistered<PlayerController>()) {
      await Get.find<PlayerController>().stopPlayback();
    }
  }
}
