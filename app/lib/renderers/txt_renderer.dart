import 'package:flutter/material.dart';

import '../widgets/reading_bottom_bar.dart';
import 'book_renderer.dart';

class TxtRenderer extends StatelessWidget {
  final List<RendererChapter> chapters;
  final int currentIndex;
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;

  const TxtRenderer({super.key, required this.chapters, required this.currentIndex, required this.theme, required this.fontSize, required this.lineHeight});

  @override
  Widget build(BuildContext context) {
    final chapter = _currentChapter;
    if (chapter == null) {
      return Center(child: Text('暂无内容', style: TextStyle(color: theme.text, fontSize: fontSize)));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: SingleChildScrollView(
        key: ValueKey('txt-$currentIndex'),
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(top: 20, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
              child: Text(chapter.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.title, height: 1.4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SelectableText(chapter.content, style: TextStyle(fontSize: fontSize, height: lineHeight, color: theme.text, letterSpacing: 0.3)),
            ),
            const SizedBox(height: 40),
            if (chapters.isNotEmpty)
              Center(child: Opacity(opacity: 0.5, child: Text(currentIndex < chapters.length - 1 ? '↓ 继续阅读 ↓' : '—— 已读完 ——', style: TextStyle(fontSize: 14, color: theme.text)))),
            const SizedBox(height: 20),
            if (chapters.isNotEmpty)
              Center(child: Text('第 ${currentIndex + 1} 章 / 共 ${chapters.length} 章', style: TextStyle(fontSize: 12, color: theme.text.withAlpha(100), height: 1.2))),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  RendererChapter? get _currentChapter => (currentIndex < 0 || currentIndex >= chapters.length) ? null : chapters[currentIndex];
}
