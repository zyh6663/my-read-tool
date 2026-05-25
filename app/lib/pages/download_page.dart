import 'dart:io';

import 'package:flutter/material.dart';

import '../services/download_manager.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await DownloadManager.getRecords();
    if (!mounted) return;
    setState(() { _records = records.reversed.toList(); _loading = false; });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$m-$d $h:$min';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('下载记录'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 56, color: theme.colorScheme.onSurface.withAlpha(80)),
                      const SizedBox(height: 16),
                      Text('暂无下载记录', style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface.withAlpha(150))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _records.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final r = _records[index];
                    final title = r['title'] as String? ?? '';
                    final path = r['path'] as String? ?? '';
                    final chapters = r['chapters'] as int? ?? 0;
                    final size = r['size'] as int? ?? 0;
                    final date = r['date'] as String? ?? '';
                    final exists = File(path).existsSync();

                    return ListTile(
                      leading: Icon(exists ? Icons.description_rounded : Icons.error_outline_rounded, size: 28, color: exists ? theme.colorScheme.primary : Colors.orange),
                      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('$chapters 章 · ${_formatSize(size)} · ${_formatDate(date)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () async {
                          await DownloadManager.removeRecord(path);
                          _load();
                        },
                      ),
                      onTap: exists ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('文件已保存至: $path'), behavior: SnackBarBehavior.floating),
                        );
                      } : null,
                    );
                  },
                ),
    );
  }
}
