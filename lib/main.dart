import 'package:btih_andriod_app/firebase_options.dart';
import 'package:btih_andriod_app/screens/splash_screen.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/services/push_notification_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_theme.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:btih_andriod_app/widgets/session_lifecycle_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_store_plus/media_store_plus.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthSession.navigatorKey = appNavigatorKey;
  await ApiConfig.init();
  await AuthSession.init();
  await GuestSession.init();

  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.init();
    await PushNotificationService.instance.init();
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'BTIHReports';
    if (AuthSession.isLoggedIn) {
      await PushNotificationService.instance.registerForCurrentUser();
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light,
      builder: (context, child) {
        return SessionLifecycleHandler(
          child: DefaultTextStyle(
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.darkText,
              height: 1.4,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      initialRoute: '/',
      routes: {
        // '/': (context) => const BillCategoryScreen(),
        '/': (context) => const SplashScreen(),
      },
    );
  }
}