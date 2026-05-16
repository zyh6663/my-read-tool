import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../widgets/reading_bottom_bar.dart';

/// EPUB / MOBI 瀵屾枃鏈覆鏌撳櫒銆?
///
/// 鍚庣杩斿洖鐨?EPUB 绔犺妭鍐呭涓?HTML 鐗囨锛?
/// 鏈粍浠朵娇鐢?[HtmlWidget] 灏嗗叾瑙ｆ瀽涓?Flutter Widget锛?
/// 骞剁粺涓€搴旂敤闃呰涓婚棰滆壊涓庡瓧鍙枫€?
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
            // 绔犺妭灏忔爣棰橈紙鐏拌壊杈呭姪鏂囧瓧锛?
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
            // 绔犺妭涓绘爣棰?
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
          // HTML 鍐呭娓叉煋
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
                // 缁熶竴鎵€鏈夋枃鏈鑹蹭互閫傞厤闃呰涓婚
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
                  currentIndex < chapters.length - 1 ? '鈥?缁х画闃呰 鈥? : '鈥?鍏ㄦ枃瀹?鈥?,
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

  /// 鑾峰彇褰撳墠绔犺妭锛岃秺鐣屾椂杩斿洖 null
  RendererChapter? get _currentChapter {
    if (currentIndex < 0 || currentIndex >= chapters.length) return null;
    return chapters[currentIndex];
  }

  /// 灏?Color 杞负 #RRGGBB 鍗佸叚杩涘埗瀛楃涓诧紝鐢ㄤ簬鍐呰仈 CSS
  String _colorToHex(Color c) {
    return '#${c.r.toRadixString(16).padLeft(2, '0')}'
        '${c.g.toRadixString(16).padLeft(2, '0')}'
        '${c.b.toRadixString(16).padLeft(2, '0')}';
  }
}