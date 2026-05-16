import 'package:flutter/material.dart';

import '../glass_widgets.dart';
import '../services/search_service.dart';

class SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback? onTap;

  const SearchResultCard({super.key, required this.result, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 72,
            child: Image.network(
              result.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: Colors.black12, alignment: Alignment.center, child: const Icon(Icons.menu_book_outlined)),
            ),
          ),
        ),
        title: Text(result.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${result.author} · ${result.sourceName}'),
            const SizedBox(height: 4),
            Text(result.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(label: Text(result.sourceName), visualDensity: VisualDensity.compact),
            Text('共${result.chapterCount}章', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
