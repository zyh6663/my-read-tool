import 'package:flutter/material.dart';

import '../auth_pages.dart';
import '../services/source_service.dart';
import '../widgets/ink_loading.dart';
import '../widgets/source_card.dart';
import '../widgets/source_import_dialog.dart';

class SourceManagePage extends StatefulWidget {
  const SourceManagePage({super.key});

  @override
  State<SourceManagePage> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends State<SourceManagePage> {
  List<BookSource> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await getToken();
      if (token == null) throw Exception('未登录');
      final items = await SourceService.listSources(token);
      setState(() => _sources = items);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openImport() async {
    await showDialog(context: context, builder: (_) => SourceImportDialog(onImported: _load));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        leading: const BackButton(),
      ),
      body: _loading
          ? const Center(child: InkLoading())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final source = _sources[index];
                return SourceCard(
                  source: source,
                  onToggle: (val) async {
                    final token = await getToken();
                    if (token == null) return;
                    final updated = BookSource(
                      id: source.id,
                      name: source.name,
                      baseUrl: source.baseUrl,
                      ruleJson: source.ruleJson,
                      enabled: val,
                      priority: source.priority,
                      isBuiltin: source.isBuiltin,
                    );
                    setState(() => _sources[index] = updated);
                    try {
                      await SourceService.updateSource(token, updated);
                    } catch (_) {
                      if (mounted) setState(() => _sources[index] = source);
                    }
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(onPressed: _openImport, child: const Icon(Icons.add)),
    );
  }
}
