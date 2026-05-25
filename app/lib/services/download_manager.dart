import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DownloadManager {
  static const _key = 'downloads';

  static Future<void> addRecord(String title, String path, int chapters, int size) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(jsonEncode({
      'title': title,
      'path': path,
      'date': DateTime.now().toIso8601String(),
      'chapters': chapters,
      'size': size,
    }));
    await prefs.setStringList(_key, list);
  }

  static Future<List<Map<String, dynamic>>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> removeRecord(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_key) ?? [])
        .where((e) => !e.contains(path))
        .toList();
    await prefs.setStringList(_key, list);
  }
}
