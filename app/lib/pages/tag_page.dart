import 'package:flutter/material.dart';

import '../animated_glass.dart';
import '../glass_widgets.dart';

class TagPage extends StatelessWidget {
  const TagPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tags = const [
      '推荐',
      '热门',
      '最近更新',
      '精选',
      '连载',
      '完结',
      '短篇',
      '经典',
      '新书',
      '收藏',
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SlideFadeIn(
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('标签专题', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('为推荐、专题和后续服务器标签系统预留的独立页面。'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SlideFadeIn(
            child: GlassPanel(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map(
                      (tag) => ActionChip(
                        label: Text(tag),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('查看标签：$tag'))),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...tags.take(4).map(
            (tag) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SlideFadeIn(
                child: GlassPanel(
                  child: ListTile(
                    leading: const Icon(Icons.local_offer_outlined),
                    title: Text(tag),
                    subtitle: const Text('可用于专题聚合、推荐流和标签浏览'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('进入标签：$tag'))),
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
