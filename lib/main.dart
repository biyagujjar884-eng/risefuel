import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_colors.dart';
import 'core/utils/date_helper.dart';
import 'data/local/quotes_local_data.dart';
import 'data/remote/quotes_api.dart';
import 'viewmodel/quotes_controller.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Initialize and inject the controller using GetX
  final controller = Get.put(QuotesController(
    localData: QuotesLocalData(),
    remoteData: QuotesApi(),
    sharedPreferences: sharedPreferences,
    dateHelper: const DateHelper(),
  ));
  
  await controller.initialize();

  runApp(const DailyQuotesApp());
}

class DailyQuotesApp extends StatelessWidget {
  const DailyQuotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<QuotesController>();
    
    return GetMaterialApp(
      title: 'Daily Quotes',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: controller.themeMode,
      home: const HomeScreen(),
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
    );

    return base.copyWith(
      textTheme: GoogleFonts.latoTextTheme(base.textTheme),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
    );

    return base.copyWith(
      textTheme: GoogleFonts.latoTextTheme(base.textTheme),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
      ),
    );
  }
}
