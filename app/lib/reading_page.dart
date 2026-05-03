import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _kBookApiBaseUrl =
    'https://super-duper-disco-pjwqr9vqgq44f6j4p-8080.app.github.dev';

// --- Reading theme definitions ---
class _ReadingTheme {
  final Color background;
  final Color text;
  final Color title;
  final Color appBar;
  final Color divider;
  final String label;

  const _ReadingTheme({
    required this.background,
    required this.text,
    required this.title,
    required this.appBar,
    required this.divider,
    required this.label,
  });

  static const eyeCare = _ReadingTheme(
    background: Color(0xFFFFF8E1),
    text: Color(0xFF5A5A5A),
    title: Color(0xFF3E3232),
    appBar: Color(0xFFFFF8E1),
    divider: Color(0xFFE8DCC8),
    label: '护眼',
  );

  static const dark = _ReadingTheme(
    background: Color(0xFF1E1E1E),
    text: Color(0xFFCCCCCC),
    title: Color(0xFFDDDDDD),
    appBar: Color(0xFF1E1E1E),
    divider: Color(0xFF333333),
    label: '暗黑',
  );

  static const parchment = _ReadingTheme(
    background: Color(0xFFF0E6D3),
    text: Color(0xFF4A4A4A),
    title: Color(0xFF3E3232),
    appBar: Color(0xFFF0E6D3),
    divider: Color(0xFFD8CEB8),
    label: '羊皮纸',
  );
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
  _ReadingTheme _currentTheme = _ReadingTheme.eyeCare;
  double _fontSize = 18.0;

  @override
  void initState() {
    super.initState();
    _loadToc();
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
      // 轻量级章节列表 API（不含正文 content）
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/books/${widget.bookId}/chapters');
      final res = await http.get(uri);
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
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final chapter =
          _Chapter.fromJson(body['chapter'] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        _content = chapter.content;
        _isLoadingContent = false;
      });
      // 端云双擎：本地存 + 后端同步
      unawaited(_saveProgressLocal());
      unawaited(_syncProgressToBackend());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
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
    // Close the Scaffold drawer and load the selected chapter
    _scaffoldKey.currentState?.closeDrawer();
    _loadChapter(index);
  }

  // ----------------------------------------------------------------
  //  端云双擎：Progress persistence (local + backend)
  // ----------------------------------------------------------------

  /// Save progress to local SharedPreferences.
  Future<void> _saveProgressLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'reading_progress_${widget.bookId}', _currentChapterIndex);
    } catch (_) {
      // silent
    }
  }

  /// Sync progress to backend (PUT), fire-and-forget.
  Future<void> _syncProgressToBackend() async {
    try {
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/books/${widget.bookId}/progress');
      await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chapter_index': _currentChapterIndex,
        }),
      );
    } catch (_) {
      // silent – local progress is the fallback
    }
  }

  /// Restore progress: first try backend GET, then local, then default 0.
  Future<void> _restoreProgress() async {
    int? restoredIndex;

    // Try backend first
    try {
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/books/${widget.bookId}/progress');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        restoredIndex = body['chapter_index'] as int?;
      }
    } catch (_) {
      // fall through to local
    }

    // Try local if backend failed
    if (restoredIndex == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        restoredIndex = prefs.getInt('reading_progress_${widget.bookId}');
      } catch (_) {}
    }

    // Validate and load
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
          // ★ 使用 Scaffold 原生的左侧 Drawer
          drawer: _buildChapterDrawer(theme),
          body: SafeArea(
            child: Stack(
              children: [
                // ============ LAYER 1: Full-screen reading content ============
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _toggleMenu(),
                    child: _buildContentBody(theme),
                  ),
                ),

                // ============ LAYER 2: Top bar (fixed) ============
                if (_showMenu)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(theme),
                  ),

                // ============ LAYER 3: Bottom bar (固定于屏幕底部！) ============
                if (_showMenu)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildBottomBar(theme),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  //  Body – 正文层，只有纯滚动文本，不含任何菜单
  // ================================================================

  Widget _buildContentBody(_ReadingTheme theme) {
    // --- Loading or error states ---
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

    // --- Normal reading body: SingleChildScrollView inside GestureDetector ---
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // chapter title
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
          // main content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SelectableText(
              _content,
              style: TextStyle(
                fontSize: _fontSize,
                height: 1.8,
                color: theme.text,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // "continue reading" hint
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ================================================================
  //  Top bar (fixed, no scrolling)
  // ================================================================

  Widget _buildTopBar(_ReadingTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.appBar,
        border: Border(
          bottom: BorderSide(color: theme.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
          child: Row(
            children: [
              // Back
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: theme.title),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              // Book title
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
    );
  }

  // ================================================================
  //  Bottom bar – 绝对固定于屏幕底部！
  //  包含：字号控制、主题切换、上一章/下一章、唯一目录按钮
  // ================================================================

  Widget _buildBottomBar(_ReadingTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.appBar,
        border: Border(
          top: BorderSide(color: theme.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- Row 1: Theme swatches & font-size controls ----
              _buildCustomizeRow(theme),
              const SizedBox(height: 6),
              // ---- Row 2: Navigation + 目录 button ----
              Row(
                children: [
                  _BottomBtn(
                    icon: Icons.skip_previous_rounded,
                    label: '上一章',
                    enabled: _currentChapterIndex > 0,
                    onTap: _currentChapterIndex > 0 ? _goToPrev : null,
                  ),
                  const SizedBox(width: 4),
                  // chapter indicator
                  Text(
                    '${_currentChapterIndex + 1} / ${_chapters.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _BottomBtn(
                    icon: Icons.skip_next_rounded,
                    label: '下一章',
                    enabled: _currentChapterIndex < _chapters.length - 1,
                    onTap: _currentChapterIndex < _chapters.length - 1
                        ? _goToNext
                        : null,
                  ),
                  const Spacer(),
                  // ★ 唯一目录按钮，呼出左侧抽屉式目录（Drawer）
                  _BottomBtn(
                    icon: Icons.list_rounded,
                    label: '目录',
                    enabled: true,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  //  Customization row  (font size + theme swatches)
  // ================================================================

  Widget _buildCustomizeRow(_ReadingTheme theme) {
    const themes = [
      _ReadingTheme.eyeCare,
      _ReadingTheme.dark,
      _ReadingTheme.parchment,
    ];

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          // -- Theme swatches --
          ...themes.map((t) {
            final isActive = t == _currentTheme;
            return GestureDetector(
              onTap: () => setState(() => _currentTheme = t),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? theme.title : t.divider,
                    width: isActive ? 2.5 : 1.5,
                  ),
                ),
                child: isActive
                    ? Icon(Icons.check, size: 14, color: theme.text)
                    : null,
              ),
            );
          }),

          const SizedBox(width: 12),
          // Divider line
          Container(
            width: 1,
            height: 20,
            color: theme.divider,
          ),
          const SizedBox(width: 12),

          // -- Font size: A- --
          _FontSizeBtn(
            label: 'A-',
            onTap: () {
              setState(() {
                _fontSize = (_fontSize - 1).clamp(12.0, 30.0);
              });
            },
            theme: theme,
          ),

          // -- Font size slider --
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.title.withAlpha(150),
                inactiveTrackColor: theme.divider,
                thumbColor: theme.title,
                overlayColor: theme.title.withAlpha(20),
                trackHeight: 2.5,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _fontSize,
                min: 12,
                max: 30,
                divisions: 18,
                label: '${_fontSize.round()}',
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            ),
          ),

          // -- Font size: A+ --
          _FontSizeBtn(
            label: 'A+',
            onTap: () {
              setState(() {
                _fontSize = (_fontSize + 1).clamp(12.0, 30.0);
              });
            },
            theme: theme,
          ),

          // font size value label
          SizedBox(
            width: 30,
            child: Text(
              '${_fontSize.round()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: theme.text.withAlpha(180),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  //  左侧抽屉目录（Scaffold Drawer）
  // ================================================================

  /// 向轻量级 API 拉取章节列表，并存到 [_chapters] 中。
  Future<void> _loadChaptersFromAPI() async {
    try {
      final uri = Uri.parse(
          '$_kBookApiBaseUrl/api/books/${widget.bookId}/chapters');
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['chapters'] as List<dynamic>? ?? [];
      final chapters = list
          .map((e) => _ChapterInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _chapters.clear();
        _chapters.addAll(chapters);
      });
    } catch (_) {
      // 静默失败，已有 TOC 数据或兜底
    }
  }

  Widget _buildChapterDrawer(_ReadingTheme theme) {
    return Drawer(
      child: Container(
        color: theme.appBar,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- DrawerHeader：显示书名 ----
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
              // ---- 章节列表 ----
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
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
                                  borderRadius: BorderRadius.circular(14),
                                  border: isCurrent
                                      ? null
                                      : Border.all(color: theme.divider),
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
                                      color: theme.title.withAlpha(180))
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
    );
  }
}

// =====================================================================
//  Reusable small widgets
// =====================================================================

/// Bottom bar icon+label button.
class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _BottomBtn({
    required this.icon,
    required this.label,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isActive ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.grey[700] : Colors.grey[350],
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.grey[600] : Colors.grey[350],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Font-size adjustment button (A- / A+).
class _FontSizeBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final _ReadingTheme theme;

  const _FontSizeBtn({
    required this.label,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.text,
          ),
        ),
      ),
    );
  }
}
