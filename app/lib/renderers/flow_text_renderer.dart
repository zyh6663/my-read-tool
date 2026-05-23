import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../widgets/reading_bottom_bar.dart';
import 'book_renderer.dart';

class FlowTextRenderer extends StatelessWidget {
  final List<RendererChapter> chapters;
  final int currentIndex;
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;

  const FlowTextRenderer({super.key, required this.chapters, required this.currentIndex, required this.theme, required this.fontSize, required this.lineHeight});

  @override
  Widget build(BuildContext context) {
    final chapter = _currentChapter;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chapter != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 24, right: 30),
              child: Text(chapter.title, style: TextStyle(fontSize: 12, color: theme.text.withAlpha(100), height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 24, right: 30),
              child: Text(chapter.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.title, height: 1.4)),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: HtmlWidget(
              chapter?.content ?? '<p></p>',
              textStyle: TextStyle(fontSize: fontSize, height: lineHeight, color: theme.text, letterSpacing: 0.3),
              customStylesBuilder: (element) => {'color': _colorToHex(theme.text)},
            ),
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
    );
  }

  RendererChapter? get _currentChapter => (currentIndex < 0 || currentIndex >= chapters.length) ? null : chapters[currentIndex];
  String _colorToHex(Color c) => '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';
}
