import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_pages.dart';
import 'config/api_config.dart';
import 'main.dart';
import 'renderers/book_renderer.dart';
import 'widgets/chapter_drawer.dart';
import 'widgets/gold_border.dart';
import 'widgets/ink_loading.dart';
import 'widgets/reading_app_bar.dart';
import 'widgets/reading_bottom_bar.dart';

const String _kBookApiBaseUrl = ApiConfig.baseUrl;
String _globalDeviceId = '';
void setGlobalDeviceId(String id) => _globalDeviceId = id;

class _ChapterInfo {
  final int index;
  final String title;
  _ChapterInfo({required this.index, required this.title});
  factory _ChapterInfo.fromJson(Map<String, dynamic> json) =>
      _ChapterInfo(index: json['index'] as int? ?? 0, title: json['title'] as String? ?? '');
}

class _Chapter {
  final int index;
  final String title;
  final String content;
  _Chapter({required this.index, required this.title, required this.content});
  factory _Chapter.fromJson(Map<String, dynamic> json) => _Chapter(
      index: json['index'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '');
}

class ReadingPage extends StatefulWidget {
  final int bookId;
  final String bookTitle;
  const ReadingPage({super.key, required this.bookId, required this.bookTitle});
  @override State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController();
  int _currentChapterIndex = 0;
  final List<_ChapterInfo> _chapters = [];
  String _content = '';
  String _bookFormat = 'txt';
  bool _isLoadingToc = true;
  bool _isLoadingContent = false;
  String? _error;
  bool _showMenu = true;
  ReadingTheme _currentTheme = ReadingTheme.darkPaper;
  double _fontSize = 18.0;
  double _baseFontSize = 18.0;
  double _lineHeight = 1.8;
  bool _isFavorited = false;
  bool _isFavoriteLoading = false;

  @override
  void initState() {
    super.initState();
    _loadToc();
    _updateStatusBar();
    _checkShelfStatus();
  }

  void _updateStatusBar() {
    final isDark = _currentTheme != ReadingTheme.lightPaper;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: _currentTheme.background,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadToc() async {
    setState(() { _isLoadingToc = true; _error = null; });
    try {
      final uri = Uri.parse('$_kBookApiBaseUrl/api/books/${widget.bookId}/chapters');
      final res = await http.get(uri, headers: {'X-User-Id': _globalDeviceId}).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['chapters'] as List<dynamic>? ?? [];
      final toc = list.map((e) => _ChapterInfo.fromJson(e as Map<String, dynamic>)).toList();
      final fmt = body['format'] as String? ?? body['book_format'] as String?;
      if (fmt != null && fmt.isNotEmpty) _bookFormat = fmt;
      if (!mounted) return;
      setState(() { _chapters..clear()..addAll(toc); });
      await _restoreProgress();
      if (!mounted) return;
      setState(() { _isLoadingToc = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoadingToc = false; });
    }
  }

  Future<void> _loadChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    setState(() {
      _currentChapterIndex = index;
      _isLoadingContent = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_kBookApiBaseUrl/api/books/${widget.bookId}/chapters/$index');
      final res = await http.get(uri, headers: {'X-User-Id': _globalDeviceId}).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final chapter = _Chapter.fromJson(body['chapter'] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() { _content = chapter.content; _isLoadingContent = false; });
      unawaited(_saveProgressLocal());
      unawaited(_syncProgressToBackend());
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoadingContent = false; });
    }
  }

  void _goToPrev() => _currentChapterIndex > 0 ? _loadChapter(_currentChapterIndex - 1) : _showEdgeToast('已经是第一章了');
  void _goToNext() => _currentChapterIndex < _chapters.length - 1 ? _loadChapter(_currentChapterIndex + 1) : _showEdgeToast('已经是最后一章了');

  void _showEdgeToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 80, left: 60, right: 60),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ));
  }

  void _jumpToChapter(int index) {
    _scaffoldKey.currentState?.closeDrawer();
    _loadChapter(index);
  }

  Future<void> _saveProgressLocal() async {
    try { final prefs = await SharedPreferences.getInstance(); await prefs.setInt('reading_progress_${widget.bookId}', _currentChapterIndex); } catch (_) {}
  }
  Future<void> _syncProgressToBackend() async {
    try { await http.put(Uri.parse('$_kBookApiBaseUrl/api/books/${widget.bookId}/progress'), headers: {'Content-Type': 'application/json', 'X-User-Id': _globalDeviceId}, body: jsonEncode({'chapter_index': _currentChapterIndex, 'position': 0.0})); } catch (_) {}
  }
  Future<void> _restoreProgress() async {
    int? restoredIndex;
    try { final res = await http.get(Uri.parse('$_kBookApiBaseUrl/api/books/${widget.bookId}/progress'), headers: {'X-User-Id': _globalDeviceId}); if (res.statusCode == 200) { final body = jsonDecode(res.body) as Map<String, dynamic>; restoredIndex = body['chapter_index'] as int?; } } catch (_) {}
    if (restoredIndex == null) { try { final prefs = await SharedPreferences.getInstance(); restoredIndex = prefs.getInt('reading_progress_${widget.bookId}'); } catch (_) {} }
    if (restoredIndex != null && restoredIndex >= 0 && restoredIndex < _chapters.length) { await _loadChapter(restoredIndex); } else { await _loadChapter(0); }
  }

  void _toggleMenu() => setState(() => _showMenu = !_showMenu);

  Future<void> _checkShelfStatus() async {
    final token = await getToken();
    if (token == null) return;
    try {
      final res = await http.get(Uri.parse('$_kBookApiBaseUrl/api/bookshelf/check/${widget.bookId}'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() => _isFavorited = body['in_shelf'] == true);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteLoading) return;
    final token = await getToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('请先登录后再收藏'), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.only(bottom: 80, left: 60, right: 60), backgroundColor: Colors.orange.shade400));
      return;
    }
    setState(() => _isFavoriteLoading = true);
    try {
      final res = await http.post(Uri.parse('$_kBookApiBaseUrl/api/bookshelf/add'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'book_id': widget.bookId}));
      if (!mounted) return;
      if (res.statusCode == 201 || res.statusCode == 409) {
        setState(() { _isFavorited = true; _isFavoriteLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功加入书架！'), behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: 80, left: 60, right: 60)));
      } else {
        setState(() => _isFavoriteLoading = false);
        _showEdgeToast('加入书架失败');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFavoriteLoading = false);
      _showEdgeToast('网络异常，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _currentTheme;
    final totalChapters = _chapters.length;
    final progressFraction = totalChapters > 0 ? (_currentChapterIndex + 1) / totalChapters : 0.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.background,
      drawer: ChapterDrawer(
        theme: theme,
        bookTitle: widget.bookTitle,
        chapters: _chapters.map((c) => ChapterDrawerItem(index: c.index, title: c.title)).toList(),
        currentIndex: _currentChapterIndex,
        onChapterSelected: _jumpToChapter,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final width = MediaQuery.of(context).size.width;
                  if (details.localPosition.dx < width / 3) {
                    _goToPrev();
                  } else if (details.localPosition.dx > width * 2 / 3) {
                    _goToNext();
                  } else {
                    _toggleMenu();
                  }
                },
                onScaleStart: (_) => _baseFontSize = _fontSize,
                onScaleUpdate: (details) {
                  setState(() => _fontSize = (_baseFontSize * details.scale).clamp(14.0, 26.0));
                },
                child: _buildContentBody(theme),
              ),
            ),
            if (totalChapters > 1 && _showMenu)
              Positioned(right: 0, top: 0, bottom: 0, child: _buildProgressBar(progressFraction)),
            if (_showMenu)
              Positioned(top: 0, left: 0, right: 0, child: ReadingAppBar(
                theme: theme,
                bookTitle: '${widget.bookTitle} · ${_currentChapterIndex + 1}/$totalChapters',
                onBackPressed: () => Navigator.pop(context),
                onFavorite: _toggleFavorite,
                isFavorited: _isFavorited,
              )),
            if (_showMenu)
              Positioned(bottom: 0, left: 0, right: 0, child: ReadingBottomBar(
                theme: theme, fontSize: _fontSize, lineHeight: _lineHeight,
                currentChapterIndex: _currentChapterIndex, totalChapters: totalChapters,
                onThemeChanged: (t) { setState(() => _currentTheme = t); _updateStatusBar(); },
                onFontSizeChanged: (v) => setState(() => _fontSize = v),
                onLineHeightChanged: (v) => setState(() => _lineHeight = v),
                onPrevChapter: _goToPrev, onNextChapter: _goToNext,
                onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double fraction) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60, bottom: 100),
      child: Container(
        width: 4,
        decoration: BoxDecoration(color: kInkGray.withAlpha(30), borderRadius: BorderRadius.circular(2)),
        margin: const EdgeInsets.only(right: 6),
        child: FractionallySizedBox(
          heightFactor: fraction, alignment: Alignment.topCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, width: 4,
            decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ),
    );
  }

  Widget _buildContentBody(ReadingTheme theme) {
    if (_isLoadingToc || (_isLoadingContent && _content.isEmpty)) {
      return const Center(child: InkLoading());
    }
    if (_error != null && _content.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: GoldBorder(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 52, color: kInkGray),
          const SizedBox(height: 16),
          Text('加载失败', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.title)),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kInkGray), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(onPressed: _loadToc, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('重试')),
        ])),
      ));
    }
    final format = bookFormatFromString(_bookFormat);
    final rendererChapters = _chapters.map((c) => RendererChapter(
      index: c.index, title: c.title,
      content: c.index == _currentChapterIndex ? _content : '',
    )).toList();
    return buildBookRenderer(
      format: format, chapters: rendererChapters, currentIndex: _currentChapterIndex,
      theme: theme, fontSize: _fontSize, lineHeight: _lineHeight,
      onPrevChapter: _goToPrev, onNextChapter: _goToNext,
    );
  }
}
