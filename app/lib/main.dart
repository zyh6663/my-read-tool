import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  static const String baseUrl = 'https://super-duper-disco-pjwqr9vqgq44f6j4p-8080.app.github.dev';

  /// Fetch all books from the backend.
  static Future<List<Book>> fetchBooks() async {
    final uri = Uri.parse('$baseUrl/api/books');
    final response = await http.get(uri);

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
    final response = await http.post(uri);

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
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load book: ${response.statusCode}');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Book.fromJson(body['book'] as Map<String, dynamic>);
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

/* -------------------------------------------------------------------------- */
/*  Book Card Widget                                                           */
/* -------------------------------------------------------------------------- */

class BookCard extends StatelessWidget {
  final Book book;

  const BookCard({super.key, required this.book});

  /// Generate a deterministic colour from the book title for the placeholder.
  Color _coverColor(String title) {
    final hash = title.hashCode;
    final hue = hash.abs() % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.55, 0.65).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final color = _coverColor(book.title);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          // ---------- Placeholder cover ----------
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withAlpha(180)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.auto_stories,
                  size: 48,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ),
          ),

          // ---------- Book info ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),

                // Author (if available)
                if (book.author.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                // Category tag chip
                if (book.category != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      book.category!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}



/* -------------------------------------------------------------------------- */
/*  Home Page                                                                  */
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

  @override
  void initState() {
    super.initState();
    _loadBooks();
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
          content: Text('上传成功：${response['title']}（${response['chapters']} 章）'),
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
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _onScanPressed,
        tooltip: 'Scan for new books',
        child: const Icon(Icons.add_photo_alternate_outlined),
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

    return RefreshIndicator(
      onRefresh: _loadBooks,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 0.68,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
 ),
          itemCount: _books.length,
          itemBuilder: (context, index) => BookCard(book: _books[index]),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  App Entry                                                                  */
/* -------------------------------------------------------------------------- */

void main() {
  runApp(const PureReaderApp());
}

class PureReaderApp extends StatelessWidget {
  const PureReaderApp({super.key});

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
      home: const BookshelfPage(),
    );
  }
}