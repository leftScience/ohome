import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ohome/app/modules/home/controllers/home_controller.dart';
import 'package:ohome/app/services/index_services.dart';
import 'package:ohome/app/utils/app_env.dart';

import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AppEnv.init();

  await IndexServices.init();
  runApp(_buildApp());
}

Widget _buildApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 876),
    minTextAdapt: true,
    builder: (context, child) => GetMaterialApp(
      title: 'oHome',
      locale: const Locale('zh', 'CN'),
      fallbackLocale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF121212),
          primary: Color(0xFFBB86FC),
          secondary: Color(0xFF03DAC6),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          leadingWidth: 40,
          titleSpacing: 4,
          titleTextStyle: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
          bodyMedium: TextStyle(
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
          bodySmall: TextStyle(
            color: Colors.white70,
            decoration: TextDecoration.none,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      navigatorObservers: const <NavigatorObserver>[],
      routingCallback: (routing) {
        if (routing?.current != Routes.MAIN) return;
        if (!Get.isRegistered<HomeController>()) return;
        Get.find<HomeController>().refreshRecentHistory();
      },
    ),
  );
}
