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
import 'pages/favorite_page.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/source_manage_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'widgets/ink_loading.dart';
import 'widgets/page_flip_route.dart';
import 'widgets/splash_page.dart';

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: kGold,
  onPrimary: kPaperDark,
  secondary: kVermilion,
  onSecondary: kCloudWhite,
  surface: Color(0xFFF5F0E8),
  onSurface: kPaperDark,
  error: kVermilion,
  onError: kCloudWhite,
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: kGold,
  onPrimary: kPaperDark,
  secondary: kVermilion,
  onSecondary: kPaperDark,
  surface: kPaperWarm,
  onSurface: kInkWarm,
  error: kVermilion,
  onError: kPaperDark,
);

Color _bgForMode(String mode) => switch (mode) {
  'warm'  => const Color(0xFF2A221D),
  'light' => const Color(0xFFF5F0E8),
  'pine'  => const Color(0xFF1A2A1A),
  'black' => const Color(0xFF000000),
  _       => const Color(0xFF1A1210),
};

class MainHomePage extends StatefulWidget {
  final VoidCallback? onLogout;
  final AppController controller;

  const MainHomePage({super.key, this.onLogout, required this.controller});

  @override
  State<MainHomePage> createState() => _MainHomeNavState();
}

class _MainHomeNavState extends State<MainHomePage> {
  int _currentIndex = 0;

  static const _navIcons = [Icons.home_rounded, Icons.bookmark_rounded, Icons.search_rounded, Icons.person_rounded];
  static const _navLabels = ['首页', '书架', '搜索', '我的'];

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
      HomePage(
        onOpenBookshelf: () => setState(() => _currentIndex = 1),
        onOpenSearch: () => setState(() => _currentIndex = 2),
        onOpenProfile: () => setState(() => _currentIndex = 3),
        onBrowseCategory: () => Navigator.of(context).push(PageFlipRoute(page: const CategoryPage())),
        onBrowseTag: () {},
      ),
      const BookShelfPage(userId: 'me', baseUrl: ApiConfig.baseUrl),
      const SearchPage(),
      ProfilePage(
        controller: widget.controller,
        onLogout: _logout,
        onOpenSettings: () => Navigator.of(context).push(PageFlipRoute(page: SettingsPage(
          settings: widget.controller.settings,
          onChanged: widget.controller.updateSettings,
          onClearCache: _clearLocalCache,
          onExport: (text) async => await Clipboard.setData(ClipboardData(text: text)),
          onManageSources: () => Navigator.of(context).push(PageFlipRoute(page: const SourceManagePage())),
        ))),
        onOpenFavorites: () => Navigator.of(context).push(PageFlipRoute(page: FavoritePage(controller: widget.controller))),
        onOpenSources: () => Navigator.of(context).push(PageFlipRoute(page: const SourceManagePage())),
      ),
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
        border: Border(top: BorderSide(color: kGold.withAlpha(40))),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_navIcons[i], size: 22, color: isSelected ? kVermilion : kInkGray),
                  const SizedBox(height: 2),
                  Text(_navLabels[i], style: TextStyle(fontSize: 10, color: isSelected ? kVermilion : kInkGray)),
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
  bool _splashDone = false;
  bool _isLoggedIn = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _updateSystemBars();
    _controller.init();
  }

  void _updateSystemBars() {
    final isLight = _controller.settings.backgroundMode == 'light';
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
    ));
  }

  void _onSplashComplete() {
    setState(() => _splashDone = true);
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/auth/me'), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
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
        final background = _bgForMode(settings.backgroundMode);
        final isLight = settings.backgroundMode == 'light';
        final scheme = isLight ? _lightScheme : _darkScheme;

        final baseTheme = ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          brightness: isLight ? Brightness.light : Brightness.dark,
          fontFamily: settings.fontFamily == 'system' ? GoogleFonts.notoSansSc().fontFamily : settings.fontFamily,
          scaffoldBackgroundColor: background,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(), TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder()},
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: kGold.withAlpha(40),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: (isLight ? Colors.white : kPaperWarm).withAlpha(220),
            foregroundColor: isLight ? kPaperDark : kInkWarm,
            elevation: 0,
          ),
        );

        Widget home;
        if (!_splashDone) {
          home = SplashPage(onComplete: _onSplashComplete);
        } else if (_isChecking) {
          home = Scaffold(backgroundColor: background, body: const Center(child: InkLoading()));
        } else if (_isLoggedIn) {
          home = MainHomePage(controller: _controller, onLogout: () => setState(() { _isLoggedIn = false; _splashDone = false; }));
        } else {
          home = LoginPage(onLogin: () => setState(() { _isLoggedIn = true; _isChecking = false; }));
        }

        return MaterialApp(
          title: 'PureReader',
          debugShowCheckedModeBanner: false,
          theme: baseTheme,
          darkTheme: baseTheme,
          themeMode: settings.backgroundMode == 'light' ? ThemeMode.light : ThemeMode.dark,
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
          home: home,
        );
      },
    );
  }
}
