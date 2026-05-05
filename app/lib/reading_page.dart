import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/reading_bottom_bar.dart';
import 'widgets/chapter_drawer.dart';
import 'widgets/reading_app_bar.dart';
import 'auth_pages.dart';
import 'config/api_config.dart';
import 'renderers/book_renderer.dart';
const String _kBookApiBaseUrl = ApiConfig.baseUrl;

/// 全局设备 ID，由 main() 在启动时写入
String _globalDeviceId = '';

/// 由外部（main.dart）调用来注入已加载/生成的 deviceId
void setGlobalDeviceId(String id) {
  _globalDeviceId = id;
}

class _ChapterInfo {
  final int index;
  final String title;
  _ChapterInfo({required this.index, required this.title});

  factory _ChapterInfo.fromJson(Map<String, dynamic> json) => _ChapterInfo(
        index: json['index'] as int? ?? 0,
        title: json['title'] as String? ?? '',
      );
}

class _Chapter {
  final int index;
  final String title;
  final String content;
  _Chapter({required this.index, required this.title, required this.content});

  factory _Chapter.fromJson(Map<String, dynamic> json) => _Chapter(
        index: json['index'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
      );
}

// =====================================================================
//                             ReadingPage
// =====================================================================

class ReadingPage extends StatefulWidget {
  final int bookId;
  final String bookTitle;

  const ReadingPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentChapterIndex = 0;
  final List<_ChapterInfo> _chapters = [];
  String _content = '';
  String _bookFormat = 'txt';
  bool _isLoadingToc = true;
  bool _isLoadingContent = false;
  String? _error;

  bool _showMenu = true;
  final ScrollController _scrollController = ScrollController();

  // --- Favorite state ---
  bool _isFavorited = false;
  bool _isFavoriteLoading = false;

  // --- Reading customization state ---
  ReadingTheme _currentTheme = ReadingTheme.eyeCare;
  double _fontSize = 18.0;
  double _lineHeight = 1.5;

  @override
  void initState() {
    super.initState();
    _loadToc();
    _updateStatusBar();
    _checkShelfStatus();
  }

  // ----------------------------------------------------------------
  //  沉浸式状态栏：跟随阅读主题自动切换
  // ----------------------------------------------------------------

  void _updateStatusBar() {
    final theme = _currentTheme;
    final isDark = theme == ReadingTheme.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: theme.background,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  //  API – TOC
  // ----------------------------------------------------------------

  Future<void> _loadToc() async {
    setState(() {
      _isLoadingToc = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/books/${widget.bookId}/chapters');
      final res = await http.get(uri, headers: {
        'X-User-Id': _globalDeviceId,
      });
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['chapters'] as List<dynamic>? ?? [];
      final toc = list
          .map((e) => _ChapterInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      // 尝试从后端响应中读取书籍格式
      final fmt = body['format'] as String? ?? body['book_format'] as String?;
      if (fmt != null && fmt.isNotEmpty) {
        _bookFormat = fmt;
      }
      if (!mounted) return;
      setState(() {
        _chapters.clear();
        _chapters.addAll(toc);
      });
      try {
        await _restoreProgress();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load chapter: $e';
        });
      }
      if (!mounted) return;
      setState(() {
        _isLoadingToc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoadingToc = false;
      });
    }
  }

  // ----------------------------------------------------------------
  //  API – Chapter loading
  // ----------------------------------------------------------------

  Future<void> _loadChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    setState(() {
      _currentChapterIndex = index;
      _isLoadingContent = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/books/${widget.bookId}/chapters/$index');
      final res = await http.get(uri, headers: {
        'X-User-Id': _globalDeviceId,
      });
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final chapter =
          _Chapter.fromJson(body['chapter'] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        _content = chapter.content;
        _isLoadingContent = false;
      });
      unawaited(_saveProgressLocal());
      unawaited(_syncProgressToBackend());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoadingContent = false;
      });
    }
  }

  // ----------------------------------------------------------------
  //  Navigation
  // ----------------------------------------------------------------

  void _goToPrev() {
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    } else {
      _showEdgeToast('已经是第一章了');
    }
  }

  void _goToNext() {
    if (_currentChapterIndex < _chapters.length - 1) {
      _loadChapter(_currentChapterIndex + 1);
    } else {
      _showEdgeToast('已经是最后一章了');
    }
  }

  void _showEdgeToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 60, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  void _jumpToChapter(int index) {
    _scaffoldKey.currentState?.closeDrawer();
    _loadChapter(index);
  }

  // ----------------------------------------------------------------
  //  端云双擎：Progress persistence (local + backend)
  // ----------------------------------------------------------------

  Future<void> _saveProgressLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'reading_progress_${widget.bookId}', _currentChapterIndex);
    } catch (_) {}
  }

  Future<void> _syncProgressToBackend() async {
    try {
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/books/${widget.bookId}/progress');
      await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': _globalDeviceId,
        },
        body: jsonEncode({
          'chapter_index': _currentChapterIndex,
          'position': 0.0,
        }),
      );
    } catch (_) {}
  }

  Future<void> _restoreProgress() async {
    int? restoredIndex;

    try {
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/books/${widget.bookId}/progress');
      final res = await http.get(uri, headers: {
        'X-User-Id': _globalDeviceId,
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        restoredIndex = body['chapter_index'] as int?;
      }
    } catch (_) {}

    if (restoredIndex == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        restoredIndex = prefs.getInt('reading_progress_${widget.bookId}');
      } catch (_) {}
    }

    if (restoredIndex != null &&
        restoredIndex >= 0 &&
        restoredIndex < _chapters.length) {
      await _loadChapter(restoredIndex);
    } else {
      await _loadChapter(0);
    }
  }

  // ----------------------------------------------------------------
  //  Menu toggle
  // ----------------------------------------------------------------

  void _toggleMenu() {
    setState(() => _showMenu = !_showMenu);
  }

  // ----------------------------------------------------------------
  //  Favorite / 加入书架
  // ----------------------------------------------------------------

  Future<void> _checkShelfStatus() async {
    final token = await getToken();
    if (token == null) return; // 未登录，跳过检查
    try {
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/bookshelf/check/${widget.bookId}');
      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'X-User-Id': token ?? '',
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _isFavorited = body['in_shelf'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteLoading) return;

    // 健壮性检查：未登录时直接提示，阻止无效请求
    final token = await getToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先登录后再收藏'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 60, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          backgroundColor: Colors.orange.shade400,
        ),
      );
      return;
    }

    setState(() => _isFavoriteLoading = true);
    try {
      final uri = Uri.parse('$_kBookApiBaseUrl/api/bookshelf/add');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': token ?? '',
        },
        body: jsonEncode({'book_id': widget.bookId}),
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        setState(() {
          _isFavorited = true;
          _isFavoriteLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已成功加入书架！'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 80, left: 60, right: 60),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        );
      } else if (res.statusCode == 409) {
        // 已在书架中
        setState(() {
          _isFavorited = true;
          _isFavoriteLoading = false;
        });
        if (!mounted) return;
        _showEdgeToast('已在书架中');
      } else {
        setState(() => _isFavoriteLoading = false);
        if (!mounted) return;
        _showEdgeToast('加入书架失败');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFavoriteLoading = false);
      if (!mounted) return;
      _showEdgeToast('网络异常，请稍后重试');
    }
  }

  // ================================================================
  //                         BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final theme = _currentTheme;
    return Builder(
      builder: (context) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: theme.background,
          drawer: ChapterDrawer(
            theme: theme,
            bookTitle: widget.bookTitle,
            chapters: _chapters
                .map((c) => ChapterDrawerItem(index: c.index, title: c.title))
                .toList(),
            currentIndex: _currentChapterIndex,
            onChapterSelected: _jumpToChapter,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _toggleMenu(),
                    child: _buildContentBody(theme),
                  ),
                ),
                if (_showMenu)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                  child: ReadingAppBar(
                    theme: theme,
                    bookTitle: widget.bookTitle,
                    onBackPressed: () => Navigator.pop(context),
                    onFavorite: _toggleFavorite,
                    isFavorited: _isFavorited,
                  ),
                  ),
                if (_showMenu)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ReadingBottomBar(
                  theme: theme,
                  fontSize: _fontSize,
                  lineHeight: _lineHeight,
                  currentChapterIndex: _currentChapterIndex,
                  totalChapters: _chapters.length,
                  onThemeChanged: (t) {
                    setState(() => _currentTheme = t);
                    _updateStatusBar();
                  },
                  onFontSizeChanged: (v) => setState(() => _fontSize = v),
                  onLineHeightChanged: (v) => setState(() => _lineHeight = v),
                  onPrevChapter: _goToPrev,
                  onNextChapter: _goToNext,
                  onOpenDrawer: () =>
                      _scaffoldKey.currentState?.openDrawer(),
                ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  //  Body
  // ================================================================

  Widget _buildContentBody(ReadingTheme theme) {
    if (_isLoadingToc || (_isLoadingContent && _content.isEmpty)) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.text.withAlpha(150),
          ),
        ),
      );
    }

    if (_error != null && _content.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('加载失败',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.title)),
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: _loadToc,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final format = bookFormatFromString(_bookFormat);

    // 将内部的 _Chapter 转换为渲染器所需的 RendererChapter
    final rendererChapters = _chapters.map((c) {
      // 当前正在展示的章节使用已加载的 _content，其余占位
      final content = (c.index == _currentChapterIndex) ? _content : '';
      return RendererChapter(
        index: c.index,
        title: c.title,
        content: content,
      );
    }).toList();

    return buildBookRenderer(
      format: format,
      chapters: rendererChapters,
      currentIndex: _currentChapterIndex,
      theme: theme,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      onPrevChapter: _goToPrev,
      onNextChapter: _goToNext,
    );
  }

  // ================================================================
  //  Top bar — 毛玻璃效果
  // ================================================================

}

