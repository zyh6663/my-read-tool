import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../widgets/reading_bottom_bar.dart';

/// EPUB / MOBI 富文本渲染器。
///
/// 后端返回的 EPUB 章节内容为 HTML 片段，
/// 本组件使用 [HtmlWidget] 将其解析为 Flutter Widget，
/// 并统一应用阅读主题颜色与字号。
class FlowTextRenderer extends StatelessWidget {
  final List<RendererChapter> chapters;
  final int currentIndex;
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;

  const FlowTextRenderer({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
  });

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
            // 章节小标题（灰色辅助文字）
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 24, right: 24),
              child: Text(
                chapter.title,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.text.withAlpha(100),
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 章节主标题
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
              child: Text(
                chapter.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.title,
                  height: 1.4,
                ),
              ),
            ),
          ],
          // HTML 内容渲染
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: HtmlWidget(
              chapter?.content ?? '<p></p>',
              textStyle: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: theme.text,
                letterSpacing: 0.3,
              ),
              customStylesBuilder: (element) {
                // 统一所有文本颜色以适配阅读主题
                return {'color': _colorToHex(theme.text)};
              },
            ),
          ),
          const SizedBox(height: 40),
          if (chapters.isNotEmpty)
            Center(
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  currentIndex < chapters.length - 1 ? '— 继续阅读 —' : '— 全文完 —',
                  style: TextStyle(fontSize: 14, color: theme.text),
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (chapters.isNotEmpty)
            Center(
              child: Text(
                '第 ${currentIndex + 1} 章 / 共 ${chapters.length} 章',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.text.withAlpha(100),
                  height: 1.2,
                ),
              ),
            ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  /// 获取当前章节，越界时返回 null
  RendererChapter? get _currentChapter {
    if (currentIndex < 0 || currentIndex >= chapters.length) return null;
    return chapters[currentIndex];
  }

  /// 将 Color 转为 #RRGGBB 十六进制字符串，用于内联 CSS
  String _colorToHex(Color c) {
    return '#${c.r.toRadixString(16).padLeft(2, '0')}'
        '${c.g.toRadixString(16).padLeft(2, '0')}'
        '${c.b.toRadixString(16).padLeft(2, '0')}';
  }
}