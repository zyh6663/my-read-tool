import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth_pages.dart';
import '../bookshelf_page.dart';
import '../config/api_config.dart';
import '../glass_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _recentQueries = <String>[];
  List<ShelfBook> _books = [];
  List<ShelfBook> _results = [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  String _query = '';
  String _filter = '全部';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ShelfBook> get _filteredResults {
    Iterable<ShelfBook> books = _results;
    if (_filter == 'EPUB') {
      books = books.where((b) => b.isEpub);
    } else if (_filter == 'TXT') {
      books = books.where((b) => b.isTxt);
    }
    return books.toList();
  }

  Future<void> _loadBookshelf() async {
    if (_loadedOnce) return;
    try {
      final token = await getToken();
      final userId = await getUserId();
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/bookshelf/list');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      });
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is Map<String, dynamic>
            ? (decoded['shelf'] as List<dynamic>? ?? decoded['data'] as List<dynamic>? ?? decoded['books'] as List<dynamic>? ?? const [])
            : const [];
        setState(() {
          _books = data.map((e) => ShelfBook.fromJson(e as Map<String, dynamic>)).toList();
          _loadedOnce = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _query = q;
      if (!_recentQueries.contains(q)) {
        _recentQueries.insert(0, q);
        if (_recentQueries.length > 6) _recentQueries.removeLast();
      }
    });
    try {
      await _loadBookshelf();
      final qLower = q.toLowerCase();
      final books = _books.where((b) => b.bookTitle.toLowerCase().contains(qLower) || b.bookAuthor.toLowerCase().contains(qLower)).toList();
      setState(() {
        _results = books;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '网络错误: $e';
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBookshelf();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredResults;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: '搜索书名、作者',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _query = '';
                                _results = [];
                              });
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(label: const Text('全部'), selected: _filter == '全部', onSelected: (_) => setState(() => _filter = '全部')),
                    ChoiceChip(label: const Text('EPUB'), selected: _filter == 'EPUB', onSelected: (_) => setState(() => _filter = 'EPUB')),
                    ChoiceChip(label: const Text('TXT'), selected: _filter == 'TXT', onSelected: (_) => setState(() => _filter = 'TXT')),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                    label: const Text('搜索书架'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_recentQueries.isNotEmpty && _query.isEmpty)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最近搜索', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recentQueries
                        .map((q) => ActionChip(label: Text(q), onPressed: () { _controller.text = q; _search(); }))
                        .toList(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_error != null)
            GlassPanel(child: Text(_error!))
          else if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_query.isEmpty)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('输入关键词开始搜索', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('支持按书名和作者快速筛选你的书架内容。'),
                  const SizedBox(height: 12),
                  Text('当前书架共 ${_books.length} 本书', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          else if (results.isEmpty)
            GlassPanel(child: Text('没有找到与“$_query”相关的书籍'))
          else
            ...results.map(
              (book) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassPanel(
                  child: ListTile(
                    leading: Icon(book.isEpub ? Icons.menu_book_rounded : Icons.text_snippet_rounded),
                    title: Text(book.bookTitle),
                    subtitle: Text(book.bookAuthor),
                    trailing: Text(book.isEpub ? 'EPUB' : 'TXT'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
