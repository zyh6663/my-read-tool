import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app_controller.dart';
import 'auth_pages.dart';
import 'bookshelf_page.dart';
import 'config/api_config.dart';
import 'pages/category_page.dart';
import 'pages/favorite_page.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/source_manage_page.dart';
import 'pages/tag_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

class MainHomePage extends StatefulWidget {
  final VoidCallback? onLogout;
  final AppController controller;

  const MainHomePage({super.key, this.onLogout, required this.controller});

  @override
  State<MainHomePage> createState() => _MainHomeNavState();
}

class _MainHomeNavState extends State<MainHomePage> {
  int _currentIndex = 0;
  static const List<String> _titles = ['首页', '书架', '我的', '设置', '收藏', '书源'];

  Future<void> _logout() async {
    await clearToken();
    widget.onLogout?.call();
  }

  Future<void> _clearLocalCache() async {
    await widget.controller.resetSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已重置本地设置')));
  }

  void _openSettings() => setState(() => _currentIndex = 3);

  Widget _buildAnimatedPage() {
    final settings = widget.controller.settings;
    final pages = [
      HomePage(
        onOpenBookshelf: () => setState(() => _currentIndex = 1),
        onOpenSearch: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
        onOpenProfile: () => setState(() => _currentIndex = 2),
        onBrowseCategory: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoryPage())),
        onBrowseTag: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TagPage())),
      ),
      const BookShelfPage(userId: 'me', baseUrl: ApiConfig.baseUrl),
      ProfilePage(controller: widget.controller, onLogout: _logout, onOpenSettings: _openSettings),
      SettingsPage(
        settings: settings,
        onChanged: widget.controller.updateSettings,
        onClearCache: _clearLocalCache,
        onExport: (text) async {
          await Clipboard.setData(ClipboardData(text: text));
        },
        onManageSources: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SourceManagePage())),
      ),
      FavoritePage(controller: widget.controller),
      const SourceManagePage(),
      const SearchPage(),
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(fade);
        return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
      },
      child: KeyedSubtree(key: ValueKey(_currentIndex), child: pages[_currentIndex]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(220),
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          if (_currentIndex == 2)
            IconButton(tooltip: '退出登录', icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _buildAnimatedPage(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(210),
        onDestinationSelected: (int index) => setState(() => _currentIndex = index),
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: '书架'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: '我的'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: '收藏'),
          NavigationDestination(icon: Icon(Icons.source_outlined), label: '书源'),
        ],
      ),
    );
  }
}

class ReaderRootApp extends StatefulWidget {
  const ReaderRootApp({super.key});

  @override
  State<ReaderRootApp> createState() => _ReaderRootAppState();
}

class _ReaderRootAppState extends State<ReaderRootApp> {
  final AppController _controller = AppController();
  bool _isLoggedIn = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    checkAuth();
    _controller.init();
  }

  Future<void> checkAuth() async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/auth/me'), headers: {'Authorization': 'Bearer $token'});
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final user = body['user'] as Map<String, dynamic>?;
          _controller.updateUser(email: user?['email'] as String?, name: user?['nickname'] as String?);
          if (mounted) setState(() => _isLoggedIn = true);
        } else {
          await clearToken();
          if (mounted) setState(() => _isLoggedIn = false);
        }
      } else {
        if (mounted) setState(() => _isLoggedIn = false);
      }
    } catch (_) {
      await clearToken();
      if (mounted) setState(() => _isLoggedIn = false);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final settings = _controller.settings;
        final lightScheme = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light);
        final darkScheme = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark);
        final background = switch (settings.backgroundMode) {
          'warm' => const Color(0xFFF7F1E8),
          'night' => const Color(0xFF0F172A),
          _ => null,
        };
        final baseTheme = ThemeData(
          colorScheme: lightScheme,
          useMaterial3: true,
          fontFamily: settings.fontFamily == 'system' ? null : settings.fontFamily,
        );
        final baseDarkTheme = ThemeData(
          colorScheme: darkScheme,
          useMaterial3: true,
          fontFamily: settings.fontFamily == 'system' ? null : settings.fontFamily,
        );
        return MaterialApp(
          title: 'PureReader',
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(scaffoldBackgroundColor: background ?? lightScheme.surface),
          darkTheme: baseDarkTheme.copyWith(scaffoldBackgroundColor: background ?? darkScheme.surface),
          themeMode: settings.flutterThemeMode,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final scale = settings.fontScale;
            final lineHeight = settings.lineHeight;
            final wrapped = DefaultTextStyle(
              style: DefaultTextStyle.of(context).style.copyWith(height: lineHeight),
              child: child ?? const SizedBox.shrink(),
            );
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(scale)),
              child: Container(color: background, child: wrapped),
            );
          },
          home: _isChecking
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _isLoggedIn
                  ? MainHomePage(controller: _controller, onLogout: () => setState(() => _isLoggedIn = false))
                  : const LoginPage(),
        );
      },
    );
  }
}
