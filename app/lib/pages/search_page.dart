import 'package:flutter/material.dart';

import '../glass_widgets.dart';
import '../services/search_service.dart';
import '../widgets/search_result_card.dart';
import 'book_import_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _recentQueries = ['科幻', '历史', '文学'];
  List<SearchResult> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch([String? value]) async {
    final q = (value ?? _searchController.text).trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _recentQueries.remove(q);
      _recentQueries.insert(0, q);
      if (_recentQueries.length > 5) _recentQueries.removeLast();
    });
    try {
      final results = await SearchService.search(q);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassPanel(
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submitSearch,
                    decoration: InputDecoration(
                      hintText: '搜索书名、作者',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _searchController.clear())),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_recentQueries.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _recentQueries.map((q) => ActionChip(label: Text(q), onPressed: () { _searchController.text = q; _submitSearch(q); })).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _results.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return SearchResultCard(
                        result: result,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookImportPage(result: result))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
