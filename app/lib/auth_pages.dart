import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'animated_glass.dart';
import 'config/api_config.dart';
import 'glass_widgets.dart';
import 'main_app.dart';
import 'pages/auth_service.dart';

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', token);
}

Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token');
}

Future<void> saveUserId(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_user_id', userId);
}

Future<String?> getUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_user_id');
}

Future<void> clearToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_token');
  await prefs.remove('auth_user_id');
}

Map<String, String> authHeaders(String? token) {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}

Future<Map<String, dynamic>> login(String email, String password) async {
  final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode == 200) return body;
  throw Exception(body['error'] ?? '登录失败');
}

Future<Map<String, dynamic>> register(String email, String password, String? nickname) async {
  final body = {'email': email, 'password': password};
  if (nickname != null && nickname.trim().isNotEmpty) body['nickname'] = nickname.trim();
  final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode == 201) return json;
  throw Exception(json['error'] ?? '注册失败');
}

Future<Map<String, dynamic>> fetchUserInfo(String token) async {
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
    headers: authHeaders(token),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode == 200) return body;
  throw Exception(body['error'] ?? '获取用户信息失败');
}

class AuthUser {
  final int id;
  final String email;
  final String nickname;
  AuthUser({required this.id, required this.email, required this.nickname});
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(id: json['id'] as int? ?? 0, email: json['email'] as String? ?? '', nickname: json['nickname'] as String? ?? '');
  String get initial => nickname.isNotEmpty ? nickname.characters.first : (email.isNotEmpty ? email.characters.first.toUpperCase() : '?');
  String get displayName => nickname.isNotEmpty ? nickname : email;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await login(_emailController.text.trim(), _passwordController.text);
      final token = result['token'] as String?;
      if (token == null) throw Exception('服务器未返回 Token');
      await saveToken(token);
      final me = await fetchUserInfo(token);
      final userJson = me['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        final userId = userJson['id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          await saveUserId(userId);
        }
      }
      AuthService.setLoggedIn(true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ReaderRootApp()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SlideFadeIn(
              child: GlassPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('PureReader', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('登录以继续', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return '请输入邮箱';
                          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(value.trim())) return '邮箱格式不正确';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onFieldSubmitted: (_) => _doLogin(),
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return '请输入密码';
                          if (value.length < 8) return '密码长度至少 8 位';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _doLogin,
                          child: _isLoading ? const CircularProgressIndicator(strokeWidth: 2.5) : const Text('登录'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          final registered = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const RegisterPage()));
                          if (registered == true && context.mounted) Navigator.of(context).pop(true);
                        },
                        child: const Text('去注册'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _doRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final nickname = _nicknameController.text.trim();
      final result = await register(_emailController.text.trim(), _passwordController.text, nickname.isNotEmpty ? nickname : null);
      final token = result['token'] as String?;
      if (token == null) throw Exception('服务器未返回 Token');
      await saveToken(token);
      final me = await fetchUserInfo(token);
      final userJson = me['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        await saveUserId((userJson['id'] ?? '').toString());
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SlideFadeIn(
              child: GlassPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return '请输入邮箱';
                          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(value.trim())) return '邮箱格式不正确';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(labelText: '昵称（可选）', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return '请输入密码';
                          if (value.length < 8) return '密码长度至少 8 位';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: '确认密码',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return '请再次输入密码';
                          if (value != _passwordController.text) return '两次输入的密码不一致';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _doRegister,
                          child: _isLoading ? const CircularProgressIndicator(strokeWidth: 2.5) : const Text('注册'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserCenterPage extends StatefulWidget {
  final VoidCallback? onLogout;
  const UserCenterPage({super.key, this.onLogout});
  @override
  State<UserCenterPage> createState() => _UserCenterPageState();
}

class _UserCenterPageState extends State<UserCenterPage> {
  AuthUser? _user;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = '未登录';
          _isLoading = false;
        });
        return;
      }
      final data = await fetchUserInfo(token);
      final userJson = data['user'] as Map<String, dynamic>?;
      if (userJson == null) throw Exception('用户数据为空');
      setState(() {
        _user = AuthUser.fromJson(userJson);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _doLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('退出')),
        ],
      ),
    );
    if (confirmed != true) return;
    await clearToken();
    if (!mounted) return;
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: _buildBody());

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 16), FilledButton(onPressed: _loadUserInfo, child: const Text('重试'))]));
    final user = _user!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SlideFadeIn(child: GlassPanel(child: Column(children: [CircleAvatar(radius: 44, child: Text(user.initial)), const SizedBox(height: 12), Text(user.displayName), Text(user.email)]))),
          const SizedBox(height: 16),
          SlideFadeIn(child: GlassPanel(child: Column(children: [ListTile(title: const Text('阅读统计'), subtitle: const Text('书籍、时长与近期趋势'), trailing: const Icon(Icons.chevron_right), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('统计功能即将接入真实数据')))),]))),
          const SizedBox(height: 16),
          SlideFadeIn(child: GlassPanel(child: ListTile(title: const Text('退出登录'), trailing: const Icon(Icons.chevron_right), onTap: _doLogout))),
        ],
      ),
    );
  }
}
