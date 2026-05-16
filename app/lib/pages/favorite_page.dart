import 'package:flutter/material.dart';

import '../animated_glass.dart';
import '../app_controller.dart';
import '../glass_widgets.dart';

class FavoritePage extends StatefulWidget {
  final AppController? controller;
  const FavoritePage({super.key, this.controller});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  @override
  Widget build(BuildContext context) {
    final favorites = widget.controller?.favorites ?? const [];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SlideFadeIn(
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('收藏', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('收藏你想快速回看的书籍，方便一键回到重要内容。', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (favorites.isEmpty)
            GlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      const Text('暂无收藏'),
                      const SizedBox(height: 6),
                      Text('在书籍详情或书架中添加收藏后，会显示在这里。', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            )
          else
            ...favorites.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SlideFadeIn(
                  child: GlassPanel(
                    child: ListTile(
                      leading: const Icon(Icons.favorite_rounded),
                      title: Text(item['bookTitle']?.toString() ?? '未命名书籍'),
                      subtitle: Text(item['bookAuthor']?.toString() ?? '未知作者'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
