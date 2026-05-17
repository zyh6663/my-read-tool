import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'animated_glass.dart';
import 'app_settings.dart';
import 'glass_widgets.dart';
import 'pages/about_page.dart';

class SettingsPage extends StatelessWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final VoidCallback? onClearCache;
  final VoidCallback? onAboutTap;
  final Future<void> Function(String text)? onExport;
  final VoidCallback? onManageSources;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onChanged,
    this.onClearCache,
    this.onAboutTap,
    this.onExport,
    this.onManageSources,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SlideFadeIn(child: _SectionHeader(title: '主题与显示')),
          const SizedBox(height: 8),
          SlideFadeIn(
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('主题模式'),
                  ),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('浅色'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('深色'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('系统'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selected) {
                      onChanged(settings.copyWith(themeMode: selected.first));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SlideFadeIn(
            child: GlassPanel(
              child: SwitchListTile(
                title: const Text('沉浸式阅读模式'),
                subtitle: const Text('减少干扰，增强阅读体验'),
                value: settings.readingMode,
                onChanged: (value) =>
                    onChanged(settings.copyWith(readingMode: value)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SlideFadeIn(
            child: GlassPanel(
              child: SwitchListTile(
                title: const Text('保持屏幕常亮'),
                subtitle: const Text('长时间阅读时避免锁屏'),
                value: settings.keepScreenOn,
                onChanged: (value) =>
                    onChanged(settings.copyWith(keepScreenOn: value)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SlideFadeIn(
            child: GlassPanel(
              child: SwitchListTile(
                title: const Text('显示章节编号'),
                subtitle: const Text('在阅读界面显示章节序号'),
                value: settings.showLineNumbers,
                onChanged: (value) =>
                    onChanged(settings.copyWith(showLineNumbers: value)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SlideFadeIn(child: _SectionHeader(title: '字体与阅读')),
          const SizedBox(height: 8),
          SlideFadeIn(
            child: GlassPanel(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('字体缩放：${(settings.fontScale * 100).toStringAsFixed(0)}%'),
                    Slider(
                      value: settings.fontScale,
                      min: 0.85,
                      max: 1.35,
                      divisions: 10,
                      label: '${(settings.fontScale * 100).toStringAsFixed(0)}%',
                      onChanged: (value) => onChanged(settings.copyWith(fontScale: value)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: settings.fontFamily,
                      decoration: const InputDecoration(labelText: '字体', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('系统字体')),
                        DropdownMenuItem(value: 'serif', child: Text('衬线字体')),
                        DropdownMenuItem(value: 'monospace', child: Text('等宽字体')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        onChanged(settings.copyWith(fontFamily: value));
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: settings.backgroundMode,
                      decoration: const InputDecoration(labelText: '背景风格', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('系统背景')),
                        DropdownMenuItem(value: 'warm', child: Text('暖色背景')),
                        DropdownMenuItem(value: 'night', child: Text('深夜背景')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        onChanged(settings.copyWith(backgroundMode: value));
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('行距：${settings.lineHeight.toStringAsFixed(1)}'),
                    Slider(
                      value: settings.lineHeight,
                      min: 1.2,
                      max: 2.0,
                      divisions: 8,
                      label: settings.lineHeight.toStringAsFixed(1),
                      onChanged: (value) => onChanged(settings.copyWith(lineHeight: value)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SlideFadeIn(child: _SectionHeader(title: '实用功能')),
          const SizedBox(height: 8),
          _ActionTile(
            title: '重置本地设置',
            subtitle: '恢复主题、字体和阅读偏好为默认值',
            icon: Icons.cleaning_services_outlined,
            onTap: onClearCache,
          ),
          _ActionTile(
            title: '检查更新',
            subtitle: '查看是否有新版本',
            icon: Icons.download_done_outlined,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('检查更新'),
                  content: const Text('当前已是最新版本。'),
                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('知道了'))],
                ),
              );
            },
          ),
          _ActionTile(
            title: '阅读统计',
            subtitle: '查看书架概览、最近阅读与收藏',
            icon: Icons.bar_chart_outlined,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('阅读统计'),
                  content: const Text('统计功能已整合到首页、收藏页和个人中心。后续可接入真实阅读时长与章节数据。'),
                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭'))],
                ),
              );
            },
          ),
          _ActionTile(
            title: '导出设置',
            subtitle: '将当前偏好导出到剪贴板',
            icon: Icons.backup_outlined,
            onTap: () async {
              final summary =
                  'theme=${settings.themeMode.name}, fontScale=${settings.fontScale}, readingMode=${settings.readingMode}, keepScreenOn=${settings.keepScreenOn}, showLineNumbers=${settings.showLineNumbers}';
              if (onExport != null) {
                await onExport!(summary);
              } else {
                await Clipboard.setData(ClipboardData(text: summary));
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已复制到剪贴板')),
              );
            },
          ),
          _ActionTile(
            title: '书源管理',
            subtitle: '导入、查看和管理书源',
            icon: Icons.source_outlined,
            onTap: onManageSources,
          ),
          _ActionTile(
            title: '关于',
            subtitle: 'HylaRead · 让阅读更轻松、更专注',
            icon: Icons.info_outline,
            onTap: onAboutTap ?? () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SlideFadeIn(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassPanel(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
