import 'package:flutter/material.dart';

import 'animated_glass.dart';
import 'app_controller.dart';
import 'glass_widgets.dart';
import 'main.dart';

class ProfilePage extends StatelessWidget {
  final AppController controller;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenFavorites;
  final VoidCallback? onOpenSources;

  const ProfilePage({
    super.key,
    required this.controller,
    this.onLogout,
    this.onOpenSettings,
    this.onOpenFavorites,
    this.onOpenSources,
  });

  @override
  Widget build(BuildContext context) {
    final email = controller.userEmail ?? '未获取到邮箱';
    final name = controller.userName?.isNotEmpty == true ? controller.userName! : 'PureReader 用户';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SlideFadeIn(
            child: GlassPanel(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: kGold.withAlpha(80),
                    child: Text(
                      name.isNotEmpty ? name.characters.first.toUpperCase() : 'U',
                      style: const TextStyle(color: kGold, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(color: kInkWarm, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(email, style: const TextStyle(color: kInkGray, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          StaggeredSlideColumn(
            children: [
              GlassPanel(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.settings_rounded, color: kGold),
                      title: const Text('设置', style: TextStyle(color: kInkWarm)),
                      subtitle: const Text('主题、字体和阅读偏好', style: TextStyle(color: kInkGray)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: kInkGray),
                      onTap: onOpenSettings,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.favorite_rounded, color: kGold),
                      title: const Text('收藏', style: TextStyle(color: kInkWarm)),
                      subtitle: const Text('查看收藏的书籍', style: TextStyle(color: kInkGray)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: kInkGray),
                      onTap: onOpenFavorites,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.source_rounded, color: kGold),
                      title: const Text('书源管理', style: TextStyle(color: kInkWarm)),
                      subtitle: const Text('导入、查看和管理书源', style: TextStyle(color: kInkGray)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: kInkGray),
                      onTap: onOpenSources,
                    ),
                  ],
                ),
              ),
              GlassPanel(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.security_rounded, color: kGold),
                      title: const Text('账号安全', style: TextStyle(color: kInkWarm)),
                      subtitle: const Text('修改密码、设备管理', style: TextStyle(color: kInkGray)),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('账号安全模块可在后端支持后接入')),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_rounded, color: kGold),
                      title: const Text('关于', style: TextStyle(color: kInkWarm)),
                      subtitle: const Text('PureReader · 让阅读更专注', style: TextStyle(color: kInkGray)),
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'PureReader',
                        applicationVersion: '1.6.0',
                        applicationLegalese: '© 2026 PureReader',
                      ),
                    ),
                  ],
                ),
              ),
              GlassPanel(
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('退出登录'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
