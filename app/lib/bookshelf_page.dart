import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_pages.dart';
import 'reading_page.dart';

/// 书架数据模型
class ShelfBook {
  final int id;
  final int bookId;
  final String addedAt;
  final String bookTitle;
  final String bookAuthor;

  ShelfBook({
    required this.id,
    required this.bookId,
    required this.addedAt,
    required this.bookTitle,
    required this.bookAuthor,
  });

  factory ShelfBook.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>? ?? {};
    return ShelfBook(
      id: json['id'] as int? ?? 0,
      bookId:json['book_id'] as int? ?? 0,
      addedAt: json['added_at'] as String? ?? '',
      bookTitle: book['title'] as String? ?? '未知书名',
      bookAuthor: book['author'] as String? ?? '未知作者',
    );
  }
}

/// 书架页面
class BookShelfPage extends StatefulWidget {
  final String userId;
  final String baseUrl;

  const BookShelfPage({
    super.key,
    required this.userId,
    required this.baseUrl,
  });

  @override
  State<BookShelfPage> createState() => _BookShelfPageState();
}

class _BookShelfPageState extends State<BookShelfPage> {
  List<ShelfBook> _books = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBookshelf();
  }

  Future<void> _fetchBookshelf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await getToken();
      final uri = Uri.parse('${widget.baseUrl}/api/bookshelf/list');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': token ?? '',
        },
      );

      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> data = map['shelf'] as List<dynamic>;
        setState(() {
          _books = data
              .map((json) => ShelfBook.fromJson(json as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '请求失败 (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '网络错误: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeBook(ShelfBook book) async {
    try {
      final token = await getToken();
      final uri =
          Uri.parse('${widget.baseUrl}/api/bookshelf/remove/${book.id}');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': token ?? '',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _books.removeWhere((b) => b.id == book.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已移除《${book.bookTitle}.》')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('绒果不能为空时觉写，只能是处入连接错误')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('附渠错误: $e')),
        );
      }
    }
  }

  void _showRemoveDialog(ShelfBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('附渠书籍'),
        content: Text('确定见我的附渠文案重新号关与记录翻译服务器'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('默认'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _removeBook(book);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _onTapBook(ShelfBook book) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => ReadingPage(
          bookId: book.bookId,
          bookTitle: book.bookTitle,
        ),
      ),
    )
        .then((_) {
      // 从阅读页返回时刷新书架数据
      _fetchBookshelf();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架&概览'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchBookshelf,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_books.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchBookshelf,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_books_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('书架空空如也', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('快去发现好书吧？', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookshelf,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return _BookCard(
            book: book,
            onTap: () => _onTapBook(book),
            onLongPress: () => _showRemoveDialog(book),
          );
        },
      ),
    );
  }
}

/// 书架书籍卡片
class _BookCard extends StatelessWidget {
  final ShelfBook book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookCard({
    required this.book,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final firstChar =
        book.bookTitle.isNotEmpty ? book.bookTitle.characters.first : '?';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.blueGrey,
                child: Text(
                  firstChar,
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                book.bookTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.bookAuthor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}