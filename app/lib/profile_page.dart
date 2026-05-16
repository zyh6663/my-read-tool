import 'package:flutter/material.dart';

import 'animated_glass.dart';
import 'app_controller.dart';
import 'auth_pages.dart';
import 'glass_widgets.dart';

class ProfilePage extends StatelessWidget {
  final AppController controller;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenSettings;

  const ProfilePage({super.key, required this.controller, this.onLogout, this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name.characters.first.toUpperCase() : 'U',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                      leading: const Icon(Icons.person_outline),
                      title: const Text('账号信息'),
                      subtitle: Text('$name · $email'),
                      trailing: const Icon(Icons.refresh),
                      onTap: () async {
                        try {
                          final token = await getToken();
                          if (token == null || token.isEmpty) return;
                          final data = await fetchUserInfo(token);
                          final user = data['user'] as Map<String, dynamic>?;
                          controller.updateUser(
                            email: user?['email'] as String?,
                            name: user?['nickname'] as String?,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('个人资料已刷新')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('刷新失败: $e')),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('前往设置'),
                      subtitle: const Text('主题、字体和阅读偏好'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onOpenSettings,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.bar_chart_outlined),
                      title: const Text('阅读统计'),
                      subtitle: const Text('查看阅读趋势与书籍概况'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('统计功能即将接入真实数据')),
                      ),
                    ),
                  ],
                ),
              ),
              GlassPanel(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.security_outlined),
                      title: const Text('账号安全'),
                      subtitle: const Text('修改密码、设备管理'),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('账号安全模块可在后端支持后接入')),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.support_agent_outlined),
                      title: const Text('帮助与反馈'),
                      subtitle: const Text('提交问题或查看使用说明'),
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'PureReader',
                        applicationVersion: '1.0.0',
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
                    icon: const Icon(Icons.logout),
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
