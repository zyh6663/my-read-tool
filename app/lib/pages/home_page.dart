import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../animated_glass.dart';
import '../glass_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                  Text('从书架继续阅读，或快速进入搜索、收藏与设置。', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(onPressed: () => context.go('/bookshelf'), icon: const Icon(Icons.bookmark_outline), label: const Text('书架')),
                      OutlinedButton.icon(onPressed: () => context.go('/search'), icon: const Icon(Icons.search), label: const Text('搜索')),
                      OutlinedButton.icon(onPressed: () => context.go('/'), icon: const Icon(Icons.settings_outlined), label: const Text('首页')),
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
                    onTap: () => context.go('/bookshelf'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.update_rounded),
                    title: const Text('最新导入'),
                    subtitle: const Text('查看最近上传到书架的书籍'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/bookshelf'),
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
                      Expanded(child: _StatCard(title: '阅读时长', value: '0 分钟', icon: Icons.timer_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(title: '书籍数量', value: '0 本', icon: Icons.menu_book_outlined)),
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
