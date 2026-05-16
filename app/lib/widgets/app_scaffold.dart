import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final Widget child;

  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTabChanged,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: '书架'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: '收藏'),
        ],
      ),
    );
  }
}
