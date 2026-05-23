import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'app_controller.dart';
import 'auth_pages.dart';
import 'bookshelf_page.dart';
import 'config/api_config.dart';
import 'main.dart';
import 'pages/category_page.dart';
import 'pages/search_page.dart';
import 'pages/source_manage_page.dart';
import 'settings_page.dart';
import 'widgets/ink_loading.dart';
import 'widgets/page_flip_route.dart';

class MainHomePage extends StatefulWidget {
  final VoidCallback? onLogout;
  final AppController controller;

  const MainHomePage({super.key, this.onLogout, required this.controller});

  @override
  State<MainHomePage> createState() => _MainHomeNavState();
}

class _MainHomeNavState extends State<MainHomePage> {
  int _currentIndex = 0;

  static const _navIcons = [
    Icons.bookmark_rounded,
    Icons.search_rounded,
    Icons.category_rounded,
  ];
  static const _navLabels = ['书架', '搜索', '分类'];

  Future<void> _logout() async {
    await clearToken();
    widget.onLogout?.call();
  }

  Future<void> _clearLocalCache() async {
    await widget.controller.resetSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已重置本地设置')));
  }

  Widget _buildAnimatedPage() {
    final pages = [
      const BookShelfPage(userId: 'me', baseUrl: ApiConfig.baseUrl),
      const SearchPage(),
      const CategoryPage(),
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: AppBar(
          backgroundColor: kPaperWarm.withAlpha(220),
          title: Text(_navLabels[_currentIndex], style: const TextStyle(color: kInkWarm)),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: '设置',
              icon: const Icon(Icons.settings_rounded, color: kInkGray),
              onPressed: () => Navigator.of(context).push(PageFlipRoute(page: SettingsPage(
                settings: widget.controller.settings,
                onChanged: widget.controller.updateSettings,
                onClearCache: _clearLocalCache,
                onExport: (text) async => await Clipboard.setData(ClipboardData(text: text)),
                onManageSources: () => Navigator.of(context).push(PageFlipRoute(page: const SourceManagePage())),
              ))),
            ),
            IconButton(
              tooltip: '退出登录',
              icon: const Icon(Icons.logout_rounded, color: kInkGray),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      body: _buildAnimatedPage(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: kPaperWarm.withAlpha(230),
        border: Border(
          top: BorderSide(color: kGold.withAlpha(40)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_navIcons.length, (i) {
          final isSelected = i == _currentIndex;
          return GestureDetector(
            onTap: () => setState(() => _currentIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              transform: isSelected
                  ? (Matrix4.identity()..setEntry(1, 3, -4.0))
                  : Matrix4.identity(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _navIcons[i],
                    size: 22,
                    color: isSelected ? kVermilion : kInkGray,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _navLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? kVermilion : kInkGray,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
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
    Future.delayed(const Duration(milliseconds: 300), () => checkAuth());
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
        final scheme = ColorScheme.fromSeed(seedColor: kGold, brightness: Brightness.dark, primary: kGold, surface: kPaperDark);
        final background = switch (settings.backgroundMode) {
          'night' => const Color(0xFF000000),
          _ => kPaperDark,
        };
        final baseTheme = ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: settings.fontFamily == 'system' ? GoogleFonts.notoSansSc().fontFamily : settings.fontFamily,
          scaffoldBackgroundColor: kPaperDark,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(), TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder()},
          ),
        );
        return MaterialApp(
          title: 'PureReader',
          debugShowCheckedModeBanner: false,
          theme: baseTheme,
          darkTheme: baseTheme,
          themeMode: ThemeMode.dark,
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
              ? Scaffold(backgroundColor: kPaperDark, body: const Center(child: InkLoading()))
              : _isLoggedIn
                  ? MainHomePage(controller: _controller, onLogout: () => setState(() => _isLoggedIn = false))
                  : const LoginPage(),
        );
      },
    );
  }
}
