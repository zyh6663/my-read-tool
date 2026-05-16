import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class BookSource {
  final int? id;
  final String name;
  final String baseUrl;
  final String ruleJson;
  final bool enabled;
  final int priority;
  final bool isBuiltin;

  const BookSource({this.id, required this.name, required this.baseUrl, required this.ruleJson, required this.enabled, required this.priority, required this.isBuiltin});

  factory BookSource.fromJson(Map<String, dynamic> json) => BookSource(
        id: json['id'] as int?,
        name: json['name'] as String? ?? '',
        baseUrl: json['base_url'] as String? ?? '',
        ruleJson: json['rule_json'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        priority: json['priority'] as int? ?? 0,
        isBuiltin: json['is_builtin'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base_url': baseUrl,
        'rule_json': ruleJson,
        'enabled': enabled,
        'priority': priority,
        'is_builtin': isBuiltin,
      };
}

class SourceService {
  static Future<List<BookSource>> listSources(String token) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/sources'), headers: _headers(token));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? '获取书源失败');
    final items = (body['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return items.map(BookSource.fromJson).toList();
  }

  static Future<BookSource> importSource(String token, BookSource source) async {
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/sources/import'), headers: _headers(token), body: jsonEncode(source.toJson()));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) throw Exception(body['error'] ?? '导入失败');
    return BookSource.fromJson((body['data'] as Map<String, dynamic>));
  }

  static Future<BookSource> updateSource(String token, BookSource source) async {
    final response = await http.put(Uri.parse('${ApiConfig.baseUrl}/api/v1/sources/${source.id}'), headers: _headers(token), body: jsonEncode(source.toJson()));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? '更新失败');
    return BookSource.fromJson((body['data'] as Map<String, dynamic>));
  }

  static Future<void> deleteSource(String token, int id) async {
    final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/api/v1/sources/$id'), headers: _headers(token));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? '删除失败');
  }

  static Future<Map<String, dynamic>> testSource(String token, BookSource source) async {
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/sources/${source.id ?? 0}/test'), headers: _headers(token), body: jsonEncode(source.toJson()));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? '测试失败');
    return body['data'] as Map<String, dynamic>;
  }

  static Future<String> getTemplate(String token) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/sources/template'), headers: _headers(token));
    if (response.statusCode != 200) throw Exception('获取模板失败');
    return response.body;
  }

  static Map<String, String> _headers(String token) => {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
}
