class AuthService {
  static bool _isLoggedIn = false;

  static bool get isLoggedIn => _isLoggedIn;

  static void setLoggedIn(bool value) {
    _isLoggedIn = value;
  }
}
