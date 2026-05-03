import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _kBookApiBaseUrl =
    'https://super-duper-disco-pjwqr9vqgq44f6j4p-8080.app.github.dev';

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
  int _currentChapterIndex = 0;
  final List<_ChapterInfo> _chapters = [];
  String _content = '';
  bool _isLoadingToc = true;
  bool _isLoadingContent = false;
  String? _error;

  bool _showBars = true;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  Future<void> _loadToc() async {
    setState(() {
      _isLoadingToc = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_kBookApiBaseUrl/api/books/${widget.bookId}');
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final book = body['book'] as Map<String, dynamic>;
      final tocJson = book['toc'] as List<dynamic>? ?? [];
      final toc = tocJson
          .map((e) => _ChapterInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _chapters.clear();
        _chapters.addAll(toc);
        // Keep _isLoadingToc = true until initial chapter load finishes
      });
      // Restore saved progress (loads the saved chapter, or chapter 0)
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
      // Persist reading progress after successfully loading a chapter
      unawaited(_saveProgress());
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

  void _goToPrev() {
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    }
  }

  void _goToNext() {
    if (_currentChapterIndex < _chapters.length - 1) {
      _loadChapter(_currentChapterIndex + 1);
    }
  }

  void _jumpToChapter(int index) {
    Navigator.pop(context);
    _loadChapter(index);
  }

  /// Persist the current chapter index for this book.
  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reading_progress_${widget.bookId}', _currentChapterIndex);
  }

  /// Restore the saved chapter index (if any) and load that chapter.
  /// If no saved progress exists, defaults to index 0.
  Future<void> _restoreProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('reading_progress_${widget.bookId}');
    final targetIndex = savedIndex ?? 0;
    // Only load if it's a valid index different from the default 0,
    // or if we have a saved value that was explicitly 0.
    if (savedIndex != null && savedIndex >= 0 && savedIndex < _chapters.length) {
      await _loadChapter(savedIndex);
    } else {
      await _loadChapter(0);
    }
  }

  void _toggleBars() {
    setState(() => _showBars = !_showBars);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F0E8),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: _buildEndDrawer(),
        appBar: _showBars
            ? AppBar(
                backgroundColor: const Color(0xFFF5F0E8),
                elevation: 0,
                scrolledUnderElevation: 0.5,
                titleSpacing: 0,
                title: Text(
                  widget.bookTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E3232),
                  ),
                ),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded,
                      color: Colors.grey.shade700),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.list_alt_rounded,
                        color: Colors.grey.shade700),
                    tooltip: '目录',
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              )
            : null,
        body: Stack(
          children: [
            _buildBody(),
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleBars,
                behavior: HitTestBehavior.translucent,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _showBars ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingToc || (_isLoadingContent && _content.isEmpty)) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2.5),
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
              const Text('加载失败',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
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

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_chapters.isNotEmpty &&
                  _currentChapterIndex < _chapters.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _chapters[_currentChapterIndex].title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                      height: 1.4,
                    ),
                  ),
                ),
              SelectableText(
                _content,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.8,
                  color: Colors.grey[800],
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 40),
              if (_chapters.isNotEmpty)
                Center(
                  child: Text(
                    _currentChapterIndex < _chapters.length - 1
                        ? '— 继续阅读 —'
                        : '— 全文完 —',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        if (_isLoadingContent)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.brown[300],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final bool hasPrev = _currentChapterIndex > 0;
    final bool hasNext = _currentChapterIndex < _chapters.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _BottomBarBtn(
                icon: Icons.list_rounded,
                label: '目录',
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              const Spacer(),
              _BottomBarBtn(
                icon: Icons.skip_previous_rounded,
                label: '上一章',
                enabled: hasPrev,
                onTap: hasPrev ? _goToPrev : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${_currentChapterIndex + 1} / ${_chapters.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              _BottomBarBtn(
                icon: Icons.skip_next_rounded,
                label: '下一章',
                enabled: hasNext,
                onTap: hasNext ? _goToNext : null,
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF5F0E8),
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text(
                '目录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Expanded(
              child: _chapters.isEmpty
                  ? Center(
                      child: Text('暂无章节',
                          style: TextStyle(color: Colors.grey[400])),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _chapters.length,
                      itemBuilder: (context, i) {
                        final ch = _chapters[i];
                        final isCurrent = i == _currentChapterIndex;
                        return Material(
                          color: isCurrent
                              ? Colors.brown.withAlpha(25)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () => _jumpToChapter(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? Colors.brown
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                      border: isCurrent
                                          ? null
                                          : Border.all(
                                              color: Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      '${ch.index}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isCurrent
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      ch.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isCurrent
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isCurrent
                                            ? Colors.brown[700]
                                            : Colors.grey[700],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrent)
                                    Icon(Icons.menu_book_rounded,
                                        size: 16, color: Colors.brown[400]),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _BottomBarBtn({
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? Colors.grey[700] : Colors.grey[350],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
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
