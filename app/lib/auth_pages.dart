import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'bookshelf_page.dart';

/* -------------------------------------------------------------------------- */
/*  Constants                                                                  */
/* -------------------------------------------------------------------------- */

// Android 模拟器 → 宿主机；真机调试改为局域网 IP，如 'http://192.168.x.x:8080'
const baseUrl = 'http://10.0.2.2:8080';

/* -------------------------------------------------------------------------- */
/*  Token 管理工具函数                                                          */
/* -------------------------------------------------------------------------- */

/// 存储 Token 到本地持久化存储
Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', token);
}

/// 读取本地持久化的 Token
Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token');
}

/// 清除本地持久化的 Token（登出）
Future<void> clearToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_token');
}

/// 为 API 请求添加 Authorization 头
Map<String, String> authHeaders(String? token) {
  return {
    'Authorization': 'Bearer ${token ?? ''}',
    'Content-Type': 'application/json',
  };
}

/* -------------------------------------------------------------------------- */
/*  API 调用函数                                                               */
/* -------------------------------------------------------------------------- */

/// 登录 — 调用 POST /api/auth/login
Future<Map<String, dynamic>> login(String email, String password) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode == 200) {
    return body; // {"message": "登录成功", "token": "eyJ..."}
  }
  throw Exception(body['error'] ?? '登录失败');
}

/// 注册 — 调用 POST /api/auth/register
Future<Map<String, dynamic>> register(
    String email, String password, String? nickname) async {
  final Map<String, dynamic> reqBody = {
    'email': email,
    'password': password,
  };
  if (nickname != null && nickname.trim().isNotEmpty) {
    reqBody['nickname'] = nickname.trim();
  }
  final response = await http.post(
    Uri.parse('$baseUrl/api/auth/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(reqBody),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode == 201) {
    return body; // {"message": "注册成功", "token": "eyJ..."}
  }
  throw Exception(body['error'] ?? '注册失败');
}

/// 获取当前用户信息 — 调用 GET /api/auth/me
Future<Map<String, dynamic>> fetchUserInfo(String token) async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/auth/me'),
    headers: authHeaders(token),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode == 200) {
    return body; // {"user": {"id": 1, "email": "...", "nickname": "..."}}
  }
  throw Exception(body['error'] ?? '获取用户信息失败');
}

/* -------------------------------------------------------------------------- */
/*  用户数据模型                                                               */
/* -------------------------------------------------------------------------- */

class AuthUser {
  final int id;
  final String email;
  final String nickname;

  AuthUser({
    required this.id,
    required this.email,
    required this.nickname,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
    );
  }

  /// 获取昵称首字（用于头像占位图）
  String get initial {
    if (nickname.isNotEmpty) return nickname.characters.first;
    if (email.isNotEmpty) return email.characters.first.toUpperCase();
    return '?';
  }

  /// 展示用名称：优先昵称，否则用邮箱
  String get displayName => nickname.isNotEmpty ? nickname : email;
}

/* ========================================================================== */
/*  登录页 LoginPage                                                           */
/* ========================================================================== */

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
      final result = await login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final token = result['token'] as String?;
      if (token == null) {
        throw Exception('服务器未返回 Token');
      }

      await saveToken(token);

      if (!mounted) return;

      // 登录成功 → 返回 true 给调用方，由 main.dart 决定跳转
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade400,
        ),
      );
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo / 标题 ──
                  Icon(
                    Icons.menu_book_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PureReader',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '登录以继续',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // ── 邮箱输入框 ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      hintText: '请输入邮箱地址',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入邮箱';
                      }
                      final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return '邮箱格式不正确';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── 密码输入框 ──
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _doLogin(),
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 8) {
                        return '密码长度至少 8 位';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── 登录按钮 ──
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _doLogin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('登录', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 去注册链接 ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '没有账号？',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: () async {
                          final registered = await Navigator.of(context)
                              .push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                          // 如果注册成功（返回 true），则同样通知父页面
                          if (registered == true && mounted) {
                            Navigator.of(context).pop(true);
                          }
                        },
                        child: const Text('去注册'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ========================================================================== */
/*  注册页 RegisterPage                                                       */
/* ========================================================================== */

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
      final result = await register(
        _emailController.text.trim(),
        _passwordController.text,
        nickname.isNotEmpty ? nickname : null,
      );

      final token = result['token'] as String?;
      if (token == null) {
        throw Exception('服务器未返回 Token');
      }

      await saveToken(token);

      if (!mounted) return;

      // 注册成功 → 返回 true 给调用方
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('注册账号'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 邮箱 ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      hintText: '请输入邮箱地址',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入邮箱';
                      }
                      final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return '邮箱格式不正确';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── 昵称（可选） ──
                  TextFormField(
                    controller: _nicknameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '昵称（可选）',
                      hintText: '给自己起个名字吧',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 密码 ──
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '至少 8 位字符',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 8) {
                        return '密码长度至少 8 位';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── 确认密码 ──
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _doRegister(),
                    decoration: InputDecoration(
                      labelText: '确认密码',
                      hintText: '再次输入密码',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请再次输入密码';
                      }
                      if (value != _passwordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── 注册按钮 ──
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _doRegister,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('注册', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 已有账号链接 ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '已有账号？',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('去登录'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ========================================================================== */
/*  用户中心页 UserCenterPage                                                  */
/* ========================================================================== */

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
      if (token == null) {
        setState(() {
          _error = '未登录';
          _isLoading = false;
        });
        return;
      }
      final data = await fetchUserInfo(token);
      final userJson = data['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        throw Exception('用户数据为空');
      }
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await clearToken();
    if (!mounted) return;
    // 通知父组件用户已登出，切换到登录页
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadUserInfo,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final user = _user!;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // ── 用户头像 & 信息区 ──
          CircleAvatar(
            radius: 44,
            backgroundColor: colorScheme.primary,
            child: Text(
              user.initial,
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // ── 功能入口卡片 ──
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                // 我的书架
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.library_books_outlined,
                        color: Color(0xFF388E3C)),
                  ),
                  title: const Text('我的书架'),
                  subtitle: const Text('查看已收藏的书籍'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookShelfPage(
                          userId: user.id.toString(),
                          baseUrl: baseUrl,
                        ),
                      ),
                    );
                  },
                ),

                const Divider(height: 1, indent: 72),

                // 阅读统计
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.bar_chart_outlined,
                        color: Color(0xFF1976D2)),
                  ),
                  title: const Text('阅读统计'),
                  subtitle: const Text('书籍: 0 本 · 阅读: 0 分钟'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // 占位：暂无详细统计
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('更多统计功能即将上线'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── 退出登录 ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _doLogout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                '退出登录',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}