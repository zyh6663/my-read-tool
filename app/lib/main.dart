import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'widgets/splash_page.dart';

const kPaperDark = Color(0xFF1A1210);
const kPaperWarm = Color(0xFF231A15);
const kGold = Color(0xFFC9A96E);
const kVermilion = Color(0xFFB5433A);
const kInkWarm = Color(0xFFE8D5B7);
const kInkGray = Color(0xFF9B8E82);
const kCloudWhite = Color(0xFFF0EBE0);

const kGoldGradient = LinearGradient(
  colors: [Color(0xFFC9A96E), Color(0xFFE8D5B7), Color(0xFFC9A96E)],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.storage.request();
  runApp(const PureReaderApp());
}

class PureReaderApp extends StatelessWidget {
  const PureReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kGold,
      brightness: Brightness.dark,
      primary: kGold,
      onPrimary: kPaperDark,
      surface: kPaperDark,
      onSurface: kInkWarm,
      surfaceContainerHighest: kPaperWarm,
      outline: kInkGray,
      error: kVermilion,
    );

    final textTheme = GoogleFonts.notoSansScTextTheme(ThemeData.dark().textTheme);
    final serifTextTheme = GoogleFonts.notoSerifScTextTheme(ThemeData.dark().textTheme);

    return MaterialApp(
      title: 'PureReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.notoSansSc().fontFamily,
        textTheme: textTheme.copyWith(
          headlineLarge: serifTextTheme.headlineLarge,
          headlineMedium: serifTextTheme.headlineMedium,
          headlineSmall: serifTextTheme.headlineSmall,
          titleLarge: serifTextTheme.titleLarge,
          titleMedium: serifTextTheme.titleMedium,
          displayLarge: serifTextTheme.displayLarge,
          displayMedium: serifTextTheme.displayMedium,
          displaySmall: serifTextTheme.displaySmall,
        ),
        scaffoldBackgroundColor: kPaperDark,
        cardTheme: CardThemeData(
          color: kPaperWarm,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kPaperWarm,
          foregroundColor: kInkWarm,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kPaperWarm.withAlpha(210),
          indicatorColor: kGold.withAlpha(40),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kPaperWarm,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kInkGray),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kInkGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kGold, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kGold,
            foregroundColor: kPaperDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kGold,
            side: const BorderSide(color: kGold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: kPaperWarm,
          selectedColor: kVermilion,
          labelStyle: const TextStyle(color: kInkWarm),
          secondaryLabelStyle: const TextStyle(color: kPaperDark),
          side: const BorderSide(color: kInkGray),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
      ),
      darkTheme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.notoSansSc().fontFamily,
        textTheme: textTheme.copyWith(
          headlineLarge: serifTextTheme.headlineLarge,
          headlineMedium: serifTextTheme.headlineMedium,
          headlineSmall: serifTextTheme.headlineSmall,
          titleLarge: serifTextTheme.titleLarge,
          titleMedium: serifTextTheme.titleMedium,
        ),
        scaffoldBackgroundColor: kPaperDark,
        cardTheme: CardThemeData(
          color: kPaperWarm,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kPaperWarm,
          foregroundColor: kInkWarm,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kPaperWarm,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kInkGray),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kInkGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kGold, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kGold,
            foregroundColor: kPaperDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: kPaperWarm,
          selectedColor: kVermilion,
          labelStyle: const TextStyle(color: kInkWarm),
          secondaryLabelStyle: const TextStyle(color: kPaperDark),
          side: const BorderSide(color: kInkGray),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
      ),
      themeMode: ThemeMode.dark,
      home: const SplashPage(),
    );
  }
}
