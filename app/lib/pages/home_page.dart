import 'package:flutter/material.dart';

import '../animated_glass.dart';
import '../glass_widgets.dart';

class HomePage extends StatelessWidget {
  final VoidCallback? onOpenBookshelf;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onBrowseCategory;
  final VoidCallback? onBrowseTag;

  const HomePage({
    super.key,
    this.onOpenBookshelf,
    this.onOpenSearch,
    this.onOpenProfile,
    this.onBrowseCategory,
    this.onBrowseTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SlideFadeIn(
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('欢迎回来', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('从首页进入分类、搜索和标签，为后续大量书籍接入做准备。', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(onPressed: onOpenBookshelf, icon: const Icon(Icons.bookmark_rounded), label: const Text('书架')),
                      OutlinedButton.icon(onPressed: onOpenSearch, icon: const Icon(Icons.search_rounded), label: const Text('搜索')),
                      OutlinedButton.icon(onPressed: onOpenProfile, icon: const Icon(Icons.person_rounded), label: const Text('我的')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TagChip(label: '推荐'),
                      _TagChip(label: '热门'),
                      _TagChip(label: '最近更新'),
                      _TagChip(label: '精选'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SlideFadeIn(
            child: GlassPanel(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.auto_stories_rounded),
                    title: const Text('最近阅读'),
                    subtitle: const Text('继续上次打开的内容'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onOpenBookshelf,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.update_rounded),
                    title: const Text('最新导入'),
                    subtitle: const Text('查看最近上传到书架的书籍'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onOpenBookshelf,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: const Text('书籍分类'),
                    subtitle: const Text('按题材与类型快速浏览未来云端书库'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onBrowseCategory,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tag_outlined),
                    title: const Text('标签浏览'),
                    subtitle: const Text('为将来的推荐和专题集合做准备'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onBrowseTag,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SlideFadeIn(
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日状态', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(title: '今日阅读', value: '暂无记录', icon: Icons.timer_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(title: '书架藏书', value: '暂无', icon: Icons.menu_book_rounded)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('推荐区', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HomeActionChip(label: '热门题材', onTap: onBrowseCategory),
                      _HomeActionChip(label: '最新上架', onTap: onOpenBookshelf),
                      _HomeActionChip(label: '本周热度', onTap: onBrowseTag),
                      _HomeActionChip(label: '继续阅读', onTap: onOpenBookshelf),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _HomeActionChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant));
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
