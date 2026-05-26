import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth_pages.dart';
import '../config/api_config.dart';
import '../animated_glass.dart';
import '../glass_widgets.dart';
import '../main.dart';
import '../reading_page.dart';
import '../widgets/ink_loading.dart';
import '../widgets/page_flip_route.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<_BookmarkItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await getToken();
      if (token == null) {
        setState(() { _error = '请先登录'; _isLoading = false; });
        return;
      }
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/bookshelf/bookmarks'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _items = list.map((e) => _BookmarkItem.fromJson(e as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _formatTime(int unixTs) {
    if (unixTs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(unixTs * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书签'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: InkLoading());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: kInkGray),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: kInkGray)),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _loadBookmarks,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.bookmark_border_rounded, size: 64, color: kGold.withAlpha(80)),
          const SizedBox(height: 16),
          const Text('暂无书签', textAlign: TextAlign.center, style: TextStyle(color: kInkGray, fontSize: 16)),
          const SizedBox(height: 8),
          Text('阅读时点击书签按钮保存进度', textAlign: TextAlign.center, style: TextStyle(color: kInkGray.withAlpha(150), fontSize: 13)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return SlideFadeIn(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassPanel(
              child: ListTile(
                leading: Icon(Icons.bookmark_rounded, color: kGold.withAlpha(200), size: 28),
                title: Text(item.bookTitle, style: const TextStyle(color: kInkWarm, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${item.totalMinutes}分钟 · 第${item.chapterIndex + 1}章 · ${_formatTime(item.lastReadAt)}',
                  style: const TextStyle(color: kInkGray, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: kInkGray),
                onTap: () {
                  Navigator.of(context).push(PageFlipRoute(
                    page: ReadingPage(bookId: item.bookId, bookTitle: item.bookTitle),
                  ));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BookmarkItem {
  final int bookId;
  final String bookTitle;
  final int chapterIndex;
  final double position;
  final int totalMinutes;
  final int lastReadAt;

  _BookmarkItem({
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
    required this.position,
    required this.totalMinutes,
    required this.lastReadAt,
  });

  factory _BookmarkItem.fromJson(Map<String, dynamic> json) {
    return _BookmarkItem(
      bookId: (json['book_id'] as num).toInt(),
      bookTitle: json['book_title'] as String? ?? '',
      chapterIndex: (json['chapter_index'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toDouble() ?? 0.0,
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      lastReadAt: (json['last_read_at'] as num?)?.toInt() ?? 0,
    );
  }
}
