import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'auth_pages.dart';
import 'reading_page.dart';

/* -------------------------------------------------------------------------- */
/*  Models                                                                     */
/* -------------------------------------------------------------------------- */

class Category {
  final int id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['ID'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class Book {
  final int id;
  final String title;
  final String author;
  final String coverUrl;
  final String format;
  final String filePath;
  final Category? category;
  final List<String> tags;
  final String content;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.format,
    required this.filePath,
    this.category,
    this.tags = const [],
    this.content = '',
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      coverUrl: json['cover_url'] as String? ?? '',
      format: json['format'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      category: json['category'] != null
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => (e as Map<String, dynamic>)['name'] as String? ?? '')
              .toList() ??
          [],
      content: json['content'] as String? ?? '',
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  API Service                                                                */
/* -------------------------------------------------------------------------- */

class BookApiService {
  // Android emulator -> 10.0.2.2 maps to host localhost
  // iOS simulator   -> use 'http://localhost:8080'
  // Physical device  -> use your machine's LAN IP
  static const String baseUrl =
      'https://super-duper-disco-pjwqr9vqgq44f6j4p-8080.app.github.dev';

  static String _deviceId = '';

  static void setDeviceId(String id) {
    _deviceId = id;
  }

  /// Fetch all books from the backend.
  static Future<List<Book>> fetchBooks() async {
    final uri = Uri.parse('$baseUrl/api/books');
    final response = await http.get(uri, headers: {
      'X-User-Id': _deviceId,
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to load books: ${response.statusCode}');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> booksJson = body['books'] as List<dynamic>? ?? [];
    return booksJson
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Trigger a scan and return the number of new books imported.
  static Future<int> triggerScan() async {
    final uri = Uri.parse('$baseUrl/api/scan');
    final response = await http.post(uri, headers: {
      'X-User-Id': _deviceId,
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to trigger scan: ${response.statusCode}');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    return body['new_books'] as int? ?? 0;
  }

  /// Fetch a single book with full content by its ID.
  static Future<Book> fetchBookById(int id) async {
    final uri = Uri.parse('$baseUrl/api/books/$id');
    final response = await http.get(uri, headers: {
      'X-User-Id': _deviceId,
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to load book: ${response.statusCode}');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Book.fromJson(body['book'] as Map<String, dynamic>);
  }

  /// Delete a book by its ID.
  static Future<void> deleteBook(int id) async {
    final uri = Uri.parse('$baseUrl/api/books/$id');
    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete book: ${response.statusCode}');
    }
  }

  /// Upload a .txt file to the backend.
  /// Uses bytes for Web compatibility (no physical path on Web).
  /// Returns the server response as Map.
  static Future<Map<String, dynamic>> uploadBook(PlatformFile file) async {
    final uri = Uri.parse('$baseUrl/api/books/upload');
    final request = http.MultipartRequest('POST', uri);

    // Use fromBytes with filename so the backend knows it's a .txt file
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

/* ========================================================================== */
/*  Cover Helpers — 根据书名生成 Morandi 色系封面                                */
/* ========================================================================== */

/// 莫兰迪色系低饱和度调色板
const List<List<int>> _morandiPalette = [
  [188, 152, 126], // 暖灰褐
  [167, 142, 138], // 玫瑰褐
  [138, 153, 145], // 鼠尾草绿
  [162, 156, 142], // 米灰
  [145, 152, 169], // 雾霾蓝
  [186, 157, 147], // 陶土粉
  [163, 153, 132], // 亚麻色
  [149, 145, 163], // 薰衣草灰
  [178, 152, 138], // 杏仁色
  [141, 157, 155], // 薄荷灰
  [170, 148, 153], // 豆沙粉
  [155, 159, 138], // 橄榄灰
  [159, 149, 163], // 紫藤灰
  [182, 162, 142], // 卡其灰
  [159, 144, 138], // 可可灰
  [148, 160, 168], // 灰蓝
  [173, 152, 159], // 烟粉
  [147, 152, 148], // 灰绿
  [168, 155, 135], // 黄褐
  [153, 148, 160], // 丁香灰
];

/// 根据书名 hashCode 从莫兰迪色板中选取一个固定颜色
Color coverColor(String title) {
  final hash = title.hashCode.abs();
  final index = hash % _morandiPalette.length;
  final rgb = _morandiPalette[index];
  return Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
}

/// 返回一个「稍深」版本的颜色用于装饰
Color _darker(Color c, [double factor = 0.85]) {
  return Color.fromARGB(
    255,
    ((c.r * 255.0).round() * factor).round().clamp(0, 255),
    ((c.g * 255.0).round() * factor).round().clamp(0, 255),
    ((c.b * 255.0).round() * factor).round().clamp(0, 255),
  );
}

/* -------------------------------------------------------------------------- */
/*  Book Card Widget — 高颜值封面                                               */
/* -------------------------------------------------------------------------- */

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onDelete;

  const BookCard({super.key, required this.book, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bg = coverColor(book.title);
    final bgDarker = _darker(bg);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: bg.withAlpha(90),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReadingPage(
              bookId: book.id,
              bookTitle: book.title,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =================== 封面区域 ===================
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // --- 封面背景（仿实体书质感） ---
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [bgDarker, bg, bg.withAlpha(200)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          book.title,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black38,
                                offset: Offset(0, 2),
                              ),
                              Shadow(
                                blurRadius: 3,
                                color: Colors.black26,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- 右上角装饰性细线（模拟精装书脊装饰） ---
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        height: 2,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(70),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),

                  // --- 删除按钮（右上角） ---
                  if (onDelete != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.transparent,
                        child: Ink(
                          decoration: const BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: onDelete,
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // =================== 下方信息栏 ===================
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor.withAlpha(30),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 书名（缩短版）
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 作者 + 分类标签
                    Row(
                      children: [
                        if (book.author.isNotEmpty)
                          Flexible(
                            child: Text(
                              book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        if (book.category != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              book.category!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                 ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  Home Pwage                                                                  */
/* -------------------------------------------------------------------------- */

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  List<Book> _books = [];
  bool _isLoading = true;
  String? _error;

  /// 搜索关键词
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// 根据搜索关键词过滤后的书籍列表
  List<Book> get _filteredBooks {
    if (_searchQuery.trim().isEmpty) return _books;
    final q = _searchQuery.trim().toLowerCase();
    return _books.where((b) => b.title.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final books = await BookApiService.fetchBooks();
      if (!mounted) return;
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onScanPressed() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanning for new books...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await BookApiService.triggerScan();
      await _loadBooks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan complete!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $e'),
          backgroundColor: Colors.red.shade300,
        ),
      );
    }
  }

  Future<void> _onDeleteBook(Book book) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除《${book.title}》吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BookApiService.deleteBook(book.id);
      if (!mounted) return;
      // Remove from local list and refresh UI
      setState(() {
        _books.removeWhere((b) => b.id == book.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除《${book.title}》'),
          backgroundColor: Colors.green.shade400,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败：$e'),
          backgroundColor: Colors.red.shade300,
        ),
      );
    }
  }

  Future<void> _onUploadPressed() async {
    try {
      // Open file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result == null || result.files.isEmpty) return;

      // ── Show loading dialog ──
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('上传中，请稍候…'),
                ],
              ),
            ),
          ),
        ),
      );

      final file = result.files.first;
      final response = await BookApiService.uploadBook(file);

      // ── Close loading dialog ──
      if (mounted) Navigator.of(context).pop();

      await _loadBooks();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '上传成功：${response['title']}（${response['chapters']} 章）'),
          backgroundColor: Colors.green.shade400,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // ── Close loading dialog if open ──
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('上传失败：$e'),
          backgroundColor: Colors.red.shade300,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PureReader'),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: Colors.transparent),
          ),
        ),
        centerTitle: true,
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary.withAlpha(170),
        actions: [
          // Upload button
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload .txt book',
            onPressed: _onUploadPressed,
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadBooks,
          ),
        ],
      ),
      body: Column(
        children: [
          // =================== 秒搜引擎 ===================
          _buildSearchBar(),
          // =================== 主体内容 ===================
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onScanPressed,
        tooltip: 'Scan for new books',
        child: const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }

  /// 搜索框
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: Theme.of(context).colorScheme.surface,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: '搜索书名…',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Unable to load books',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _loadBooks,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.book, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Your bookshelf is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to scan for books',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // 过滤后为空
    if (_filteredBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配的书名',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '试试其他关键词吧',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBooks,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            childAspectRatio: 0.7,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filteredBooks.length,
          itemBuilder: (context, index) => BookCard(
            book: _filteredBooks[index],
            onDelete: () => _onDeleteBook(_filteredBooks[index]),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  App Entry                                                                  */
/* -------------------------------------------------------------------------- */

String _globalDeviceId = '';

void setGlobalDeviceId(String id) {
  _globalDeviceId = id;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 生成/加载 device_id
  final prefs = await SharedPreferences.getInstance();
  String deviceId = prefs.getString('device_id') ?? '';
  if (deviceId.isEmpty) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }
  BookApiService.setDeviceId(deviceId);
  setGlobalDeviceId(deviceId);

  runApp(const PureReaderApp());
}

class PureReaderApp extends StatefulWidget {
  const PureReaderApp({super.key});

  @override
  State<PureReaderApp> createState() => _PureReaderAppState();
}

class _PureReaderAppState extends State<PureReaderApp> {
  bool _isLoggedIn = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  void checkAuth() async {
    final token = await getToken();
    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          // Token 有效，进入主页
          if (mounted) setState(() => _isLoggedIn = true);
          if (mounted) setState(() => _isChecking = false);
          return;
        }
        // 状态码非 200（如 401）：Token 已过期，清除并重新登录
        if (response.statusCode == 401) {
          await clearToken();
        }
      } catch (_) {
        // 网络异常等，不清除 Token，允许离线进入主页
        if (mounted) {
          setState(() => _isLoggedIn = true);
          setState(() => _isChecking = false);
        }
        return;
      }
    }
    if (mounted) setState(() => _isLoggedIn = false);
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PureReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: _isChecking
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _isLoggedIn
              ? _MainHomePage(
                  onLogout: () => setState(() => _isLoggedIn = false),
                )
              : const LoginPage(),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  主页面（底部导航：书架 + 我的）                                           */
/* -------------------------------------------------------------------------- */

class _MainHomePage extends StatefulWidget {
  final VoidCallback onLogout;

  const _MainHomePage({required this.onLogout});

  @override
  State<_MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<_MainHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const BookshelfPage(),
          UserCenterPage(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
