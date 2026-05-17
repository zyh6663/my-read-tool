import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth_pages.dart';
import '../services/source_service.dart';

class SourceImportDialog extends StatefulWidget {
  final VoidCallback? onImported;
  const SourceImportDialog({super.key, this.onImported});

  @override
  State<SourceImportDialog> createState() => _SourceImportDialogState();
}

class _SourceImportDialogState extends State<SourceImportDialog> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() => _loading = true);
    try {
      final raw = _controller.text.trim();
      String body;
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        try {
          final resp = await http.get(Uri.parse(raw));
          if (resp.statusCode != 200) {
            throw Exception('网络请求失败，状态码：${resp.statusCode}');
          }
          body = resp.body;
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('网络获取失败：$e');
        }
        try {
          jsonDecode(body);
        } catch (_) {
          throw Exception('获取的内容不是合法 JSON');
        }
      } else {
        body = raw;
      }
      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      final token = await getToken();
      if (token == null || token.isEmpty) throw Exception('未登录');
      final source = BookSource.fromJson(jsonMap);
      await SourceService.importSource(token, source);
      if (!mounted) return;
      widget.onImported?.call();
      Navigator.of(context).pop(true);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('已存在') || msg.contains('duplicate')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重复书源：$msg')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入书源'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          maxLines: 14,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '粘贴书源 JSON'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: _loading ? null : _import, child: Text(_loading ? '导入中...' : '导入')),
      ],
    );
  }
}
