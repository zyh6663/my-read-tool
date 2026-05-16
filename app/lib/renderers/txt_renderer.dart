import 'package:flutter/material.dart';
import '../widgets/reading_bottom_bar.dart';

/// TXT 婊氬姩娓叉煋鍣ㄣ€?
///
/// 淇濇寔浼犵粺鐨勬暣绔犲崟椤垫粴鍔ㄦā寮忥紝閫傚悎绾枃鏈槄璇汇€?
class TxtRenderer extends StatelessWidget {
  final List<RendererChapter> chapters;
  final int currentIndex;
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;

  const TxtRenderer({
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

    if (chapter == null) {
      return Center(
        child: Text(
          '鏆傛棤鍐呭',
          style: TextStyle(color: theme.text, fontSize: fontSize),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 绔犺妭鏍囬
          Padding(
            padding: const EdgeInsets.only(
                bottom: 20, left: 24, right: 24),
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
          // 姝ｆ枃鍐呭锛堝彲閫夋嫨澶嶅埗锛?
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SelectableText(
              chapter.content,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: theme.text,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // 搴曢儴杩涘害鎻愮ず
          if (chapters.isNotEmpty)
            Center(
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  currentIndex < chapters.length - 1
                      ? '鈥?缁х画闃呰 鈥?
                      : '鈥?鍏ㄦ枃瀹?鈥?,
                  style: TextStyle(fontSize: 14, color: theme.text),
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (chapters.isNotEmpty)
            Center(
              child: Text(
                '绗?${currentIndex + 1} 绔?/ 鍏?${chapters.length} 绔?,
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

  RendererChapter? get _currentChapter {
    if (currentIndex < 0 || currentIndex >= chapters.length) return null;
    return chapters[currentIndex];
  }
}