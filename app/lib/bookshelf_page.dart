import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'animated_glass.dart';
import 'auth_pages.dart';
import 'glass_widgets.dart';
import 'main.dart';
import 'reading_page.dart';
import 'widgets/ink_loading.dart';

class ShelfBook {
  final int id;
  final int bookId;
  final String addedAt;
  final String bookTitle;
  final String bookAuthor;
  final String fileType;

  ShelfBook({required this.id, required this.bookId, required this.addedAt, required this.bookTitle, required this.bookAuthor, required this.fileType});

  factory ShelfBook.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>? ?? json['Book'] as Map<String, dynamic>? ?? json['book_info'] as Map<String, dynamic>? ?? {};
    final type = (json['format'] as String? ?? json['file_type'] as String? ?? book['format'] as String? ?? book['file_type'] as String? ?? '').toLowerCase();
    return ShelfBook(
      id: (json['id'] as num?)?.toInt() ?? (json['ID'] as num?)?.toInt() ?? 0,
      bookId: (json['book_id'] as num?)?.toInt() ?? (json['bookId'] as num?)?.toInt() ?? (json['bookID'] as num?)?.toInt() ?? 0,
      addedAt: json['added_at'] as String? ?? json['addedAt'] as String? ?? '',
      bookTitle: book['title'] as String? ?? json['title'] as String? ?? json['book_title'] as String? ?? '未知书名',
      bookAuthor: book['author'] as String? ?? json['author'] as String? ?? json['book_author'] as String? ?? '未知作者',
      fileType: type,
    );
  }

  bool get isEpub => fileType == 'epub' || bookTitle.toLowerCase().endsWith('.epub');
  bool get isTxt => fileType == 'txt' || bookTitle.toLowerCase().endsWith('.txt');
}

class BookShelfPage extends StatefulWidget {
  final String userId;
  final String baseUrl;

  const BookShelfPage({super.key, required this.userId, required this.baseUrl});

  @override
  State<BookShelfPage> createState() => _BookShelfPageState();
}

class _BookShelfPageState extends State<BookShelfPage> {
  final TextEditingController _searchController = TextEditingController();
  List<ShelfBook> _books = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  String _query = '';

  List<ShelfBook> get _filteredBooks {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _books;
    return _books.where((book) {
      return book.bookTitle.toLowerCase().contains(q) || book.bookAuthor.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchBookshelf();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _uploadBookFile(PlatformFile file) async {
    final uri = Uri.parse('${widget.baseUrl}/api/books/upload');
    final request = http.MultipartRequest('POST', uri);
    final token = await getToken();
    final userId = await getUserId();
    if (token != null && token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
    if (userId != null && userId.isNotEmpty) request.headers['X-User-Id'] = userId;
    request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('上传失败：${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _pickAndUploadBook() async {
    if (_isUploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'epub'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) throw Exception('无法读取文件内容');
      setState(() => _isUploading = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('正在上传 ${file.name} ...')));
      }
      final response = await _uploadBookFile(file);
      await _fetchBookshelf(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传成功：${response['title'] ?? file.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _fetchBookshelf({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final token = await getToken();
      final userId = await getUserId();
      final uri = Uri.parse('${widget.baseUrl}/api/bookshelf/list');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      });
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is Map<String, dynamic>
            ? (decoded['shelf'] as List<dynamic>? ?? decoded['data'] as List<dynamic>? ?? decoded['books'] as List<dynamic>? ?? const [])
            : decoded is List<dynamic>
                ? decoded
                : const [];
        if (!mounted) return;
        setState(() {
          _books = data.map((json) => ShelfBook.fromJson(json as Map<String, dynamic>)).toList();
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _errorMessage = '登录已失效，请重新登录';
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = '请求失败 (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '网络错误: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeBook(ShelfBook book) async {
    try {
      final token = await getToken();
      final userId = await getUserId();
      final uri = Uri.parse('${widget.baseUrl}/api/bookshelf/remove/${book.id}');
      final response = await http.delete(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      });
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() => _books.removeWhere((b) => b.id == book.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已移除《${book.bookTitle}》')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('移除失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  void _showRemoveDialog(ShelfBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPaperWarm,
        title: const Text('移除书籍', style: TextStyle(color: kInkWarm)),
        content: Text('确定要将《${book.bookTitle}》从书架移除吗？', style: const TextStyle(color: kInkWarm)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(onPressed: () { Navigator.of(ctx).pop(); _removeBook(book); }, child: const Text('确认')),
        ],
      ),
    );
  }

  void _onTapBook(ShelfBook book) {
    final title = book.isEpub ? '${book.bookTitle} [EPUB]' : book.bookTitle;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReadingPage(bookId: book.bookId, bookTitle: title))).then((_) async {
      await _fetchBookshelf(showLoading: false);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: _buildBody());

  Widget _buildBody() {
    if (_isLoading) return const Center(child: InkLoading());
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTopTools(),
            const Spacer(),
            Icon(Icons.cloud_off_rounded, size: 58, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => _fetchBookshelf(), icon: const Icon(Icons.refresh), label: const Text('重试')),
            const Spacer(),
          ],
        ),
      );
    }

    final books = _filteredBooks;
    return RefreshIndicator(
      onRefresh: () => _fetchBookshelf(showLoading: false),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: _buildTopTools())),
          if (books.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(80, 80),
                      painter: _OpenBookPainter(),
                    ),
                    const SizedBox(height: 16),
                    const Text('书中自有黄金屋', style: TextStyle(color: kInkGray, fontSize: 14, letterSpacing: 4)),
                    const SizedBox(height: 10),
                    if (_query.isEmpty) FilledButton.icon(onPressed: _isUploading ? null : _pickAndUploadBook, icon: const Icon(Icons.upload_file_rounded), label: const Text('上传本地图书')),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.74, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: books.length,
                itemBuilder: (context, index) => _buildBookCard(context, books[index], index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopTools() {
    return SlideFadeIn(
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: '搜索书名或作者',
                      prefixIcon: const Icon(Icons.search_rounded, color: kInkGray),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, color: kInkGray),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      hintStyle: const TextStyle(color: kInkGray),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: kPaperDark.withAlpha(120),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _ToolButton(icon: Icons.refresh_rounded, tooltip: '刷新', onTap: () => _fetchBookshelf(showLoading: false)),
                const SizedBox(width: 8),
                _ToolButton(icon: _isUploading ? Icons.hourglass_top_rounded : Icons.upload_file_rounded, tooltip: '上传本地图书', onTap: _isUploading ? null : _pickAndUploadBook),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, size: 16, color: kGold),
                const SizedBox(width: 6),
                Text('共 ${_books.length} 本', style: const TextStyle(color: kInkWarm, fontSize: 12)),
                if (_query.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('· 匹配 ${_filteredBooks.length} 本', style: const TextStyle(color: kInkWarm, fontSize: 12)),
                ],
                const Spacer(),
                const Text('下拉也可刷新', style: TextStyle(color: kInkGray, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _bookColor(String title) {
    final hash = title.hashCode;
    return Color.fromARGB(255, (hash & 0xFF) % 128 + 64, ((hash >> 8) & 0xFF) % 128 + 64, ((hash >> 16) & 0xFF) % 128 + 64);
  }

  Widget _buildBookCard(BuildContext context, ShelfBook book, int index) {
    final color = _bookColor(book.bookTitle);
    final firstChar = book.bookTitle.isNotEmpty ? book.bookTitle.characters.first : '?';
    final shortTitle = book.bookTitle.length > 20 ? '${book.bookTitle.substring(0, 20)}…' : book.bookTitle;

    return TweenAnimationBuilder<double>(
      key: ValueKey(book.id),
      tween: Tween(begin: 0.96, end: 1),
      duration: Duration(milliseconds: 280 + index * 28),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
      child: SlideFadeIn(
        child: GestureDetector(
          onTap: () => _onTapBook(book),
          onLongPress: () => _showRemoveDialog(book),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGold.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                  ),
                  alignment: Alignment.center,
                  child: Text(firstChar, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(shortTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInkWarm)),
                      if (book.bookAuthor.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(book.bookAuthor, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: kInkGray)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: kInkGray, size: 18),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToolButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kPaperWarm.withAlpha(120),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGold.withAlpha(30)),
            ),
            child: Icon(icon, color: kGold),
          ),
        ),
      ),
    );
  }
}

class _OpenBookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.35;
    final h = size.height * 0.4;

    final pagePaint = Paint()
      ..color = kInkGray.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final coverPaint = Paint()
      ..color = kInkGray.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Left page
    final leftPath = Path()
      ..moveTo(cx, cy - h)
      ..quadraticBezierTo(cx - w * 0.5, cy - h * 0.7, cx - w, cy)
      ..quadraticBezierTo(cx - w * 0.5, cy + h * 0.7, cx, cy + h);
    canvas.drawPath(leftPath, pagePaint);

    // Right page
    final rightPath = Path()
      ..moveTo(cx, cy - h)
      ..quadraticBezierTo(cx + w * 0.5, cy - h * 0.7, cx + w, cy)
      ..quadraticBezierTo(cx + w * 0.5, cy + h * 0.7, cx, cy + h);
    canvas.drawPath(rightPath, pagePaint);

    // Spine line
    canvas.drawLine(Offset(cx, cy - h), Offset(cx, cy + h), coverPaint);

    // Gold dot at spine
    final dotPaint = Paint()
      ..color = kGold.withAlpha(150)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
