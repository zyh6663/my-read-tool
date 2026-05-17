import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../animated_glass.dart';
import '../auth_pages.dart';
import '../glass_widgets.dart';
import '../services/search_service.dart';
import '../services/source_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _keywordController = TextEditingController();

  List<SearchResult> _results = [];
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;

  List<BookSource> _sources = [];
  int? _selectedSourceId;
  bool _loadingSources = true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    try {
      final token = await getToken();
      if (token != null) {
        final sources = await SourceService.listSources(token);
        if (!mounted) return;
        setState(() {
          _sources = sources;
          _selectedSourceId = sources.isNotEmpty ? sources.first.id : null;
          _loadingSources = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingSources = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSources = false);
    }
  }

  Future<void> _search() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
      _results = [];
    });

    try {
      final results = await SearchService.search(
        keyword,
        source: _selectedSourceId?.toString(),
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------
  // 点击书籍 → 获取详情 → 底部弹出章节列表
  // ---------------------------------------------------------------
  Future<void> _onBookTap(SearchResult book) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在获取《${book.title}》详情…'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final detail = await SearchService.getDetail(book.sourceId, book.sourceBookId);
      if (!mounted) return;
      _showBookDetailSheet(detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取详情失败: $e')),
      );
    }
  }

  // ---------------------------------------------------------------
  // 底部弹出：书籍详情 + 章节列表（可点击跳转阅读）
  // ---------------------------------------------------------------
  void _showBookDetailSheet(BookDetail detail) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽指示条
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 书名
              Text(
                detail.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),

              // 作者
              Text(
                '作者: ${detail.author.isNotEmpty ? detail.author : '未知'}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),

              // 来源 & 章节数
              Text(
                '来源: ${detail.sourceName}  ·  共 ${detail.chapterCount} 章',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),

              // 简介
              if (detail.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  detail.description,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),

              // 章节标题
              Text(
                '目录',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // 章节列表（全部可点击）
              ...detail.chapters.map(
                (ch) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${ch.index}. ${ch.title}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openChapter(detail, ch);
                  },
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // 点击章节 → 获取内容 → 跳转阅读页
  // ---------------------------------------------------------------
  Future<void> _openChapter(BookDetail book, ChapterItem chapter) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在加载《${chapter.title}》…'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final detail = await SearchService.getDetail(book.sourceId, book.sourceBookId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ReaderPage(
            book: detail,
            chapter: chapter,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }

  // ---------------------------------------------------------------
  // 构建 UI
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ---- 搜索栏 ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SlideFadeIn(
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      // 书源下拉
                      _buildSourceDropdown(theme),
                      const SizedBox(width: 8),
                      // 搜索输入框
                      Expanded(
                        child: TextField(
                          controller: _keywordController,
                          decoration: const InputDecoration(
                            hintText: '输入书名或作者',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      // 搜索按钮
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _loading ? null : _search,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---- 内容区 ----
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceDropdown(ThemeData theme) {
    if (_loadingSources) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return DropdownButton<int>(
      value: _selectedSourceId,
      underline: const SizedBox.shrink(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      items: _sources.map((s) {
        return DropdownMenuItem<int>(
          value: s.id,
          child: Text(
            s.name,
            style: theme.textTheme.bodySmall,
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedSourceId = val);
      },
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 加载中
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 错误
    if (_error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 空状态
    if (_hasSearched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到相关书籍',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    // 初始状态（尚未搜索）
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 56,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              '输入关键词搜索书籍',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    // 搜索结果列表
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final book = _results[index];
        return _SearchResultTile(
          book: book,
          onTap: () => _onBookTap(book),
        );
      },
    );
  }
}

// ===================================================================
// 搜索结果列表项
// ===================================================================
class _SearchResultTile extends StatelessWidget {
  final SearchResult book;
  final VoidCallback onTap;

  const _SearchResultTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SlideFadeIn(
        child: GlassPanel(
          padding: const EdgeInsets.all(0),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 封面
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 60,
                      child: book.coverUrl.isNotEmpty
                          ? Image.network(
                              book.coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fallbackCover(theme),
                            )
                          : _fallbackCover(theme),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 书名 & 作者
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.author.isNotEmpty ? book.author : '未知作者',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 来源标签
                  if (book.sourceName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book.sourceName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackCover(ThemeData theme) {
    return Container(
      width: 44,
      height: 60,
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Icon(
        Icons.menu_book,
        size: 24,
        color: theme.colorScheme.primary.withOpacity(0.5),
      ),
    );
  }
}

// ===================================================================
// 简易阅读页：通过 HTTP GET 章节 URL 获取内容并展示
// ===================================================================
class _ReaderPage extends StatefulWidget {
  final BookDetail book;
  final ChapterItem chapter;

  const _ReaderPage({required this.book, required this.chapter});

  @override
  State<_ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<_ReaderPage> {
  bool _loading = true;
  String? _error;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      final res = await http.get(Uri.parse(widget.chapter.url));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      // 尝试解析 JSON；如果源返回纯文本则直接使用 body
      String text;
      try {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        text = json['content'] as String? ?? json['data'] as String? ?? res.body;
      } catch (_) {
        text = res.body;
      }
      if (!mounted) return;
      setState(() {
        _content = text;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapter.title),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              )),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _fetchContent();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(
                      _content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.8,
                      ),
                    ),
                  ),
      ),
    );
  }
}