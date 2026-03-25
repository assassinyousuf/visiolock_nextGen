import 'package:flutter/material.dart';

import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/receiver_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sender_screen.dart';
import 'utils/app_colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      surface: AppColors.backgroundLight,
      onPrimary: AppColors.backgroundDark,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      surface: AppColors.backgroundDark,
      onPrimary: AppColors.backgroundDark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VisioLock',
      theme: ThemeData(
        colorScheme: lightScheme,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        SenderScreen.routeName: (_) => const SenderScreen(),
        ReceiverScreen.routeName: (_) => const ReceiverScreen(),
        HistoryScreen.routeName: (_) => const HistoryScreen(),
        SettingsScreen.routeName: (_) => const SettingsScreen(),
      },
    );
  }
}
