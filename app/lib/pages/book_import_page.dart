import 'dart:async';

import 'package:flutter/material.dart';

import '../glass_widgets.dart';
import '../services/search_service.dart';
import '../widgets/ink_loading.dart';

class BookImportPage extends StatefulWidget {
  final SearchResult result;
  const BookImportPage({super.key, required this.result});

  @override
  State<BookImportPage> createState() => _BookImportPageState();
}

class _BookImportPageState extends State<BookImportPage> {
  BookDetail? _detail;
  double _progress = 0;
  String? _taskId;
  bool _loading = true;
  bool _importing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await SearchService.getDetail(widget.result.sourceId, widget.result.sourceBookId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importBook() async {
    setState(() => _importing = true);
    try {
      final resp = await SearchService.importBook(widget.result.sourceId, widget.result.sourceBookId);
      _taskId = resp.taskId;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (_taskId == null) return;
        final prog = await SearchService.getProgress(_taskId!);
        if (!mounted) return;
        setState(() => _progress = prog.progress);
        if (prog.progress >= 1) {
          _timer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入完成')));
          if (mounted) Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('书籍详情')),
      body: _loading
          ? const Center(child: InkLoading())
          : _detail == null
              ? const Center(child: Text('加载失败'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassPanel(
                      child: Row(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_detail!.coverUrl, width: 110, height: 150, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 110, height: 150, color: Colors.black12))),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_detail!.title, style: Theme.of(context).textTheme.titleLarge), Text(_detail!.author), const SizedBox(height: 8), Text(_detail!.description)])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('章节预览（共${_detail!.chapterCount}章）'), const SizedBox(height: 8), ..._detail!.chapters.take(10).map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${c.index + 1}. ${c.title}')))]),
                    ),
                    const SizedBox(height: 16),
                    if (_importing || _progress > 0)
                      LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _importing ? null : _importBook, child: Text(_importing ? '导入中...' : '导入到我的书库')),
                  ],
                ),
    );
  }
}
