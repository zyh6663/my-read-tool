import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class SearchResult {
  final int sourceId;
  final String sourceName;
  final String sourceBookId;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final int chapterCount;

  const SearchResult({required this.sourceId, required this.sourceName, required this.sourceBookId, required this.title, required this.author, required this.description, required this.coverUrl, required this.chapterCount});

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        sourceId: json['source_id'] as int? ?? 0,
        sourceName: json['source_name'] as String? ?? '',
        sourceBookId: json['source_book_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        description: json['description'] as String? ?? '',
        coverUrl: json['cover_url'] as String? ?? '',
        chapterCount: json['chapter_count'] as int? ?? 0,
      );
}

class ChapterItem {
  final int index;
  final String title;
  final String url;
  const ChapterItem({required this.index, required this.title, required this.url});
  factory ChapterItem.fromJson(Map<String, dynamic> json) => ChapterItem(index: json['index'] as int? ?? 0, title: json['title'] as String? ?? '', url: json['url'] as String? ?? '');
}

class BookDetail extends SearchResult {
  final List<ChapterItem> chapters;
  const BookDetail({required super.sourceId, required super.sourceName, required super.sourceBookId, required super.title, required super.author, required super.description, required super.coverUrl, required super.chapterCount, required this.chapters});
  factory BookDetail.fromJson(Map<String, dynamic> json) => BookDetail(
        sourceId: json['source_id'] as int? ?? 0,
        sourceName: json['source_name'] as String? ?? '',
        sourceBookId: json['source_book_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        description: json['description'] as String? ?? '',
        coverUrl: json['cover_url'] as String? ?? '',
        chapterCount: json['chapter_count'] as int? ?? 0,
        chapters: (json['chapters'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>().map(ChapterItem.fromJson).toList(),
      );
}

class ImportResponse {
  final String taskId;
  const ImportResponse({required this.taskId});
  factory ImportResponse.fromJson(Map<String, dynamic> json) => ImportResponse(taskId: json['task_id'] as String? ?? '');
}

class ImportProgress {
  final String taskId;
  final double progress;
  const ImportProgress({required this.taskId, required this.progress});
  factory ImportProgress.fromJson(Map<String, dynamic> json) => ImportProgress(taskId: json['task_id'] as String? ?? '', progress: (json['progress'] as num?)?.toDouble() ?? 0);
}

class SearchService {
  static Future<List<SearchResult>> search(String keyword, {int page = 1, String? source}) async {
    final query = <String, String>{'keyword': keyword, 'page': '$page'};
    if (source != null) {
      query['source'] = source;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/search').replace(queryParameters: query);
    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(body['error'] ?? '搜索失败');
    return (body['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>().map(SearchResult.fromJson).toList();
  }

  static Future<BookDetail> getDetail(int sourceId, String bookId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/search/detail').replace(queryParameters: {'source_id': '$sourceId', 'book_id': bookId});
    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(body['error'] ?? '获取详情失败');
    return BookDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  static Future<ImportResponse> importBook(int sourceId, String bookId, {String? chapterRange}) async {
    final payload = <String, dynamic>{'source_id': sourceId, 'book_id': bookId};
    if (chapterRange != null) payload['chapter_range'] = chapterRange;
    final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/books/import'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 202) throw Exception(body['error'] ?? '导入失败');
    return ImportResponse.fromJson(body['data'] as Map<String, dynamic>);
  }

  static Future<ImportProgress> getProgress(String taskId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/books/import/progress').replace(queryParameters: {'task_id': taskId});
    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(body['error'] ?? '获取进度失败');
    return ImportProgress.fromJson(body['data'] as Map<String, dynamic>);
  }
}
