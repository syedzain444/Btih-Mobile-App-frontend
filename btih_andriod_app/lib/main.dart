// import 'package:btih_andriod_app/screens/bill_category_screen.dart';
import 'package:btih_andriod_app/screens/splash_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_theme.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) {
        return DefaultTextStyle(
          style: AppTypography.roboto(
            fontSize: 14,
            color: AppColors.darkText,
            height: 1.4,
          ),
          child: child ?? const SizedBox.shrink(),
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