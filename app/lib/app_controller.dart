import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

class AppController extends ChangeNotifier {
  static const _favoritesKey = 'favorite_books';
  static const _recentKey = 'recent_books';

  AppSettings _settings = const AppSettings.defaults();
  String? _userEmail;
  String? _userName;
  bool _keepLoggedIn = true;
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _recentBooks = [];

  AppSettings get settings => _settings;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  bool get keepLoggedIn => _keepLoggedIn;
  List<Map<String, dynamic>> get favorites => List.unmodifiable(_favorites);
  List<Map<String, dynamic>> get recentBooks => List.unmodifiable(_recentBooks);

  Future<void> init() async {
    _settings = await AppSettings.load();
    final prefs = await SharedPreferences.getInstance();
    _favorites = _readList(prefs.getStringList(_favoritesKey));
    _recentBooks = _readList(prefs.getStringList(_recentKey));
    notifyListeners();
  }

  List<Map<String, dynamic>> _readList(List<String>? values) {
    return values
            ?.map((e) => jsonDecode(e) as Map<String, dynamic>)
            .toList(growable: true) ??
        [];
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites.map(jsonEncode).toList());
    await prefs.setStringList(_recentKey, _recentBooks.map(jsonEncode).toList());
  }

  Future<void> updateSettings(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await next.save();
  }

  AppSettings get defaultSettings => const AppSettings.defaults();

  Future<void> resetSettings() async {
    _settings = const AppSettings.defaults();
    notifyListeners();
    await _settings.save();
  }

  void updateUser({String? email, String? name}) {
    _userEmail = email;
    _userName = name;
    notifyListeners();
  }

  void setKeepLoggedIn(bool value) {
    _keepLoggedIn = value;
    notifyListeners();
  }

  Future<void> addRecentBook(Map<String, dynamic> book) async {
    _recentBooks.removeWhere((item) => item['bookId'] == book['bookId']);
    _recentBooks.insert(0, book);
    if (_recentBooks.length > 10) _recentBooks = _recentBooks.take(10).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> toggleFavorite(Map<String, dynamic> book) async {
    final id = book['bookId'];
    final index = _favorites.indexWhere((item) => item['bookId'] == id);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.insert(0, book);
    }
    notifyListeners();
    await _persist();
  }

  bool isFavorite(dynamic bookId) => _favorites.any((item) => item['bookId'] == bookId);
}
