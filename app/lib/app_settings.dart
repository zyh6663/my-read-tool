import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _themeModeKey = 'themeMode';
  static const _fontScaleKey = 'fontScale';
  static const _readingModeKey = 'readingMode';
  static const _keepScreenOnKey = 'keepScreenOn';
  static const _showLineNumbersKey = 'showLineNumbers';
  static const _backgroundKey = 'backgroundMode';
  static const _fontFamilyKey = 'fontFamily';
  static const _lineHeightKey = 'lineHeight';

  final ThemeMode themeMode;
  final double fontScale;
  final bool readingMode;
  final bool keepScreenOn;
  final bool showLineNumbers;
  final String backgroundMode;
  final String fontFamily;
  final double lineHeight;

  const AppSettings({
    required this.themeMode,
    required this.fontScale,
    required this.readingMode,
    required this.keepScreenOn,
    required this.showLineNumbers,
    required this.backgroundMode,
    required this.fontFamily,
    required this.lineHeight,
  });

  const AppSettings.defaults()
      : themeMode = ThemeMode.system,
        fontScale = 1.0,
        readingMode = true,
        keepScreenOn = false,
        showLineNumbers = false,
        backgroundMode = 'system',
        fontFamily = 'system',
        lineHeight = 1.6;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? fontScale,
    bool? readingMode,
    bool? keepScreenOn,
    bool? showLineNumbers,
    String? backgroundMode,
    String? fontFamily,
    double? lineHeight,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      readingMode: readingMode ?? this.readingMode,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  ThemeMode get flutterThemeMode => themeMode;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_themeModeKey) ?? 'system';
    final fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
    return AppSettings(
      themeMode: switch (modeName) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      fontScale: fontScale.clamp(0.85, 1.35),
      readingMode: prefs.getBool(_readingModeKey) ?? true,
      keepScreenOn: prefs.getBool(_keepScreenOnKey) ?? false,
      showLineNumbers: prefs.getBool(_showLineNumbersKey) ?? false,
      backgroundMode: prefs.getString(_backgroundKey) ?? 'system',
      fontFamily: prefs.getString(_fontFamilyKey) ?? 'system',
      lineHeight: prefs.getDouble(_lineHeightKey) ?? 1.6,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    await prefs.setDouble(_fontScaleKey, fontScale);
    await prefs.setBool(_readingModeKey, readingMode);
    await prefs.setBool(_keepScreenOnKey, keepScreenOn);
    await prefs.setBool(_showLineNumbersKey, showLineNumbers);
    await prefs.setString(_backgroundKey, backgroundMode);
    await prefs.setString(_fontFamilyKey, fontFamily);
    await prefs.setDouble(_lineHeightKey, lineHeight);
  }
}
