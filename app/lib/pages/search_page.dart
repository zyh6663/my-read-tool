import 'package:flutter/material.dart';

import '../animated_glass.dart';
import '../glass_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  final List<String> _recentQueries = ['科幻', '历史', '文学'];

  final List<_SearchBook> _books = const [
    _SearchBook(title: '三体', author: '刘慈欣', category: '科幻', tags: ['热门', '推荐']),
    _SearchBook(title: '活着', author: '余华', category: '文学', tags: ['经典', '推荐']),
    _SearchBook(title: '明朝那些事儿', author: '当年明月', category: '历史', tags: ['热门', '连载']),
    _SearchBook(title: '未来简史', author: '尤瓦尔·赫拉利', category: '人文', tags: ['推荐', '思考']),
    _SearchBook(title: '雪国', author: '川端康成', category: '文学', tags: ['经典']),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<_SearchBook> get _filteredBooks {
    final q = _searchController.text.trim().toLowerCase();
    final activeCategory = _tabController.index == 1 ? '文学' : _tabController.index == 2 ? '历史' : null;
    return _books.where((book) {
      final matchesQuery = q.isEmpty || book.title.toLowerCase().contains(q) || book.author.toLowerCase().contains(q) || book.tags.any((t) => t.toLowerCase().contains(q));
      final matchesCategory = activeCategory == null || book.category == activeCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  void _submitSearch(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    setState(() {
      _recentQueries.remove(q);
      _recentQueries.insert(0, q);
      if (_recentQueries.length > 5) _recentQueries.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final books = _filteredBooks;
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassPanel(
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submitSearch,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索书名、作者、标签',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setState(() => _searchController.clear()),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    onTap: (_) => setState(() {}),
                    tabs: const [
                      Tab(text: '全部'),
                      Tab(text: '文学'),
                      Tab(text: '历史'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_recentQueries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recentQueries.map((q) => ActionChip(label: Text(q), onPressed: () => setState(() => _searchController.text = q))).toList(),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (books.isEmpty)
                  GlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          const Text('没有找到相关书籍'),
                        ],
                      ),
                    ),
                  )
                else
                  ...books.map((book) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassPanel(
                          child: ListTile(
                            leading: const Icon(Icons.menu_book_rounded),
                            title: Text(book.title),
                            subtitle: Text('${book.author} · ${book.category}'),
                            trailing: Wrap(
                              spacing: 6,
                              children: book.tags.map((tag) => Chip(label: Text(tag), visualDensity: VisualDensity.compact)).toList(),
                            ),
                          ),
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBook {
  final String title;
  final String author;
  final String category;
  final List<String> tags;

  const _SearchBook({required this.title, required this.author, required this.category, required this.tags});
}
