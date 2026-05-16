import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth_pages.dart';
import '../bookshelf_page.dart';
import '../config/api_config.dart';
import '../glass_widgets.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<ShelfBook> _books = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await getToken();
      final userId = await getUserId();
      if (userId == null || userId.isEmpty) {
        setState(() {
          _error = '未找到用户 ID，请重新登录';
          _loading = false;
        });
        return;
      }
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/bookshelf/list'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'X-User-Id': userId,
        },
      );
      debugPrint(response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is Map<String, dynamic>
            ? (decoded['shelf'] as List<dynamic>? ?? decoded['data'] as List<dynamic>? ?? decoded['books'] as List<dynamic>? ?? const [])
            : const [];
        setState(() {
          _books = data.map((e) => ShelfBook.fromJson(e as Map<String, dynamic>)).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = '加载失败 (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络错误: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: GlassPanel(
          child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), FilledButton(onPressed: _loadBooks, child: const Text('重试'))]),
        ),
      );
    }
    if (_books.isEmpty) {
      return Center(
        child: GlassPanel(
          child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.library_books_outlined, size: 64), SizedBox(height: 12), Text('还没有书籍，去上传吧')]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadBooks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassPanel(
              child: ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(book.bookTitle),
                subtitle: Text(book.bookAuthor),
              ),
            ),
          );
        },
      ),
    );
  }
}
