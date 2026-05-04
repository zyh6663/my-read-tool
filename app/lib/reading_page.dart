import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/reading_bottom_bar.dart';
const String _kBookApiBaseUrl =
    'https://super-duper-disco-pjwqr9vqgq44f6j4p-8080.app.github.dev';

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
  bool _isLoadingToc = true;
  bool _isLoadingContent = false;
  String? _error;

  bool _showMenu = true;
  final ScrollController _scrollController = ScrollController();

  // --- Reading customization state ---
  ReadingTheme _currentTheme = ReadingTheme.eyeCare;
  double _fontSize = 18.0;
  double _lineHeight = 1.5;

  @override
  void initState() {
    super.initState();
    _loadToc();
    _updateStatusBar();
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
          drawer: _buildChapterDrawer(theme),
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
                    child: _buildTopBar(theme),
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

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, bottom: 100),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Column(
          key: ValueKey<int>(_currentChapterIndex),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_chapters.isNotEmpty &&
                _currentChapterIndex < _chapters.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 24, right: 24),
                child: Text(
                  _chapters[_currentChapterIndex].title,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.text.withAlpha(100),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (_chapters.isNotEmpty &&
                _currentChapterIndex < _chapters.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
                child: Text(
                  _chapters[_currentChapterIndex].title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.title,
                    height: 1.4,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SelectableText(
                _content,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: _lineHeight,
                  color: theme.text,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (_chapters.isNotEmpty)
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Text(
                    _currentChapterIndex < _chapters.length - 1
                        ? '— 继续阅读 —'
                        : '— 全文完 —',
                    style: TextStyle(fontSize: 14, color: theme.text),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (_chapters.isNotEmpty)
              Center(
                child: Text(
                  '第 ${_currentChapterIndex + 1} 章 / 共 ${_chapters.length} 章',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.text.withAlpha(100),
                    height: 1.2,
                  ),
                ),
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // ================================================================
  //  Top bar — 毛玻璃效果
  // ================================================================

  Widget _buildTopBar(ReadingTheme theme) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: theme.appBar.withAlpha(160),
            border: Border(
              bottom:
                  BorderSide(color: theme.divider.withAlpha(80), width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: theme.title),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.bookTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.title,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  //  左侧抽屉目录 — 毛玻璃效果
  // ================================================================

  Widget _buildChapterDrawer(ReadingTheme theme) {
    return Drawer(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: theme.appBar.withAlpha(170),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.divider),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 36, color: theme.title.withAlpha(200)),
                          const SizedBox(height: 12),
                          Text(
                            widget.bookTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.title,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共 ${_chapters.length} 章',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.text.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _chapters.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.text.withAlpha(120),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '加载章节列表中...',
                                    style: TextStyle(
                                      color: theme.text.withAlpha(120),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _chapters.length,
                            itemBuilder: (context, i) {
                              final ch = _chapters[i];
                              final isCurrent = i == _currentChapterIndex;
                              return Material(
                                color: isCurrent
                                    ? theme.title.withAlpha(25)
                                    : Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  leading: Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? theme.title.withAlpha(180)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: isCurrent
                                          ? null
                                          : Border.all(
                                              color: theme.divider),
                                    ),
                                    child: Text(
                                      '${ch.index}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isCurrent
                                            ? Colors.white
                                            : theme.text.withAlpha(180),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    ch.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: isCurrent
                                          ? theme.title
                                          : theme.text,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isCurrent
                                      ? Icon(Icons.bookmark_rounded,
                                          size: 18,
                                          color:
                                              theme.title.withAlpha(180))
                                      : null,
                                  onTap: () => _jumpToChapter(i),
                                ),
                              );
                            },
                          ),
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

