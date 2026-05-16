import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static bool isLoggedIn = false;
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = (prefs.getString('auth_token') ?? '').isNotEmpty;
    notifier.value = isLoggedIn;
  }

  static void setLoggedIn(bool value) {
    isLoggedIn = value;
    notifier.value = value;
  }
}
