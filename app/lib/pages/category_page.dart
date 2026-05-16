import 'package:flutter/material.dart';

import '../animated_glass.dart';
import '../glass_widgets.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = const [
      _CategoryItem(name: '科幻', description: '未来、宇宙、想象力'),
      _CategoryItem(name: '文学', description: '散文、小说、诗歌'),
      _CategoryItem(name: '历史', description: '人物、王朝、纪实'),
      _CategoryItem(name: '人文', description: '哲学、社科、思考'),
      _CategoryItem(name: '悬疑', description: '推理、案件、反转'),
      _CategoryItem(name: '商业', description: '管理、创业、职场'),
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
                  Text('书籍分类', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('用于未来接入海量书库时的分类浏览与推荐入口。'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final item = categories[index];
              return SlideFadeIn(
                child: GlassPanel(
                  child: InkWell(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('进入 ${item.name} 分类'))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.primary),
                          const Spacer(),
                          Text(item.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(item.description, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryItem {
  final String name;
  final String description;
  const _CategoryItem({required this.name, required this.description});
}
