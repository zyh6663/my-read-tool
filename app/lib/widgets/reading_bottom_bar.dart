import 'dart:ui';

import 'package:flutter/material.dart';

import '../main.dart';

class ReadingTheme {
  final Color background;
  final Color text;
  final Color title;
  final Color appBar;
  final Color divider;
  final String label;

  const ReadingTheme({required this.background, required this.text, required this.title, required this.appBar, required this.divider, required this.label});

  static const darkPaper = ReadingTheme(background: Color(0xFF1A1210), text: Color(0xFFE8D5B7), title: Color(0xFFE8D5B7), appBar: Color(0xFF231A15), divider: Color(0xFF3A2A20), label: '暗宣纸');
  static const warmWood = ReadingTheme(background: Color(0xFF2A221D), text: Color(0xFFE8D5B7), title: Color(0xFFE8D5B7), appBar: Color(0xFF231A15), divider: Color(0xFF4A3A2A), label: '暖木色');
  static const lightPaper = ReadingTheme(background: Color(0xFFF5F0E8), text: Color(0xFF3C2415), title: Color(0xFF3C2415), appBar: Color(0xFFE8DCC8), divider: Color(0xFFD4C5A9), label: '亮宣纸');
  static const pineGreen = ReadingTheme(background: Color(0xFF1A2A1A), text: Color(0xFFC9D5B7), title: Color(0xFFC9D5B7), appBar: Color(0xFF152015), divider: Color(0xFF2A3A2A), label: '松石绿');
  static const pureBlackGold = ReadingTheme(background: Color(0xFF000000), text: Color(0xFFC9A96E), title: Color(0xFFC9A96E), appBar: Color(0xFF0A0A0A), divider: Color(0xFF2A2A2A), label: '纯黑金');

  static const List<ReadingTheme> all = [darkPaper, warmWood, lightPaper, pineGreen, pureBlackGold];
}

class ReadingBottomBar extends StatelessWidget {
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;
  final int currentChapterIndex;
  final int totalChapters;
  final ValueChanged<ReadingTheme> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onOpenDrawer;

  const ReadingBottomBar({super.key, required this.theme, required this.fontSize, required this.lineHeight, required this.currentChapterIndex, required this.totalChapters, required this.onThemeChanged, required this.onFontSizeChanged, required this.onLineHeightChanged, required this.onPrevChapter, required this.onNextChapter, required this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: theme.appBar.withAlpha(220),
            border: Border(top: BorderSide(color: kGold.withAlpha(60), width: 0.6)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CustomizeRow(theme: theme, fontSize: fontSize, lineHeight: lineHeight, onThemeChanged: onThemeChanged, onFontSizeChanged: onFontSizeChanged, onLineHeightChanged: onLineHeightChanged),
                  _ReadingStats(currentChapter: currentChapterIndex + 1, totalChapters: totalChapters, fontSize: fontSize, lineHeight: lineHeight, theme: theme),
                  Row(
                    children: [
                      _BottomBtn(icon: Icons.skip_previous_rounded, label: '上一章', enabled: currentChapterIndex > 0, onTap: currentChapterIndex > 0 ? onPrevChapter : null),
                      const SizedBox(width: 8),
                      Text('${currentChapterIndex + 1} / $totalChapters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text)),
                      const SizedBox(width: 8),
                      _BottomBtn(icon: Icons.skip_next_rounded, label: '下一章', enabled: currentChapterIndex < totalChapters - 1, onTap: currentChapterIndex < totalChapters - 1 ? onNextChapter : null),
                      const Spacer(),
                      _BottomBtn(icon: Icons.list_rounded, label: '目录', enabled: true, onTap: onOpenDrawer),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomizeRow extends StatelessWidget {
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;
  final ValueChanged<ReadingTheme> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;

  const _CustomizeRow({required this.theme, required this.fontSize, required this.lineHeight, required this.onThemeChanged, required this.onFontSizeChanged, required this.onLineHeightChanged});

  @override
  Widget build(BuildContext context) {
    final themes = ReadingTheme.all;
    return Column(
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              ...themes.map((t) {
                final isActive = t == theme;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onThemeChanged(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: t.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: isActive ? kGold : t.divider, width: isActive ? 2.5 : 1.0),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(isActive ? 40 : 10), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: isActive ? const Icon(Icons.check, size: 12, color: kGold) : null,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Container(width: 1, height: 18, color: theme.divider),
              const SizedBox(width: 8),
              _FontSizeBtn(label: 'A-', onTap: () => onFontSizeChanged((fontSize - 1).clamp(12.0, 30.0)), theme: theme),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(activeTrackColor: kGold.withAlpha(150), inactiveTrackColor: theme.divider, thumbColor: kGold, overlayColor: kGold.withAlpha(20), trackHeight: 2.5, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                  child: Slider(value: fontSize, min: 12, max: 30, divisions: 18, label: '${fontSize.round()}', onChanged: onFontSizeChanged),
                ),
              ),
              _FontSizeBtn(label: 'A+', onTap: () => onFontSizeChanged((fontSize + 1).clamp(12.0, 30.0)), theme: theme),
              SizedBox(width: 34, child: Text('${fontSize.round()}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: theme.text.withAlpha(180)))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 26,
          child: Row(
            children: [
              Text('行距', style: TextStyle(fontSize: 11, color: theme.text.withAlpha(150))),
              const SizedBox(width: 6),
              _LineHeightBtn(theme: theme, label: '紧凑', isActive: (lineHeight - 1.2).abs() < 0.01, onTap: () => onLineHeightChanged(1.2)),
              const SizedBox(width: 4),
              _LineHeightBtn(theme: theme, label: '标准', isActive: (lineHeight - 1.5).abs() < 0.01, onTap: () => onLineHeightChanged(1.5)),
              const SizedBox(width: 4),
              _LineHeightBtn(theme: theme, label: '宽松', isActive: (lineHeight - 1.8).abs() < 0.01, onTap: () => onLineHeightChanged(1.8)),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(activeTrackColor: kGold.withAlpha(150), inactiveTrackColor: theme.divider, thumbColor: kGold, overlayColor: kGold.withAlpha(20), trackHeight: 2.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                  child: Slider(value: lineHeight, min: 1.0, max: 2.0, divisions: 20, label: lineHeight.toStringAsFixed(1), onChanged: onLineHeightChanged),
                ),
              ),
              SizedBox(width: 28, child: Text(lineHeight.toStringAsFixed(1), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: theme.text.withAlpha(180)))),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineHeightBtn extends StatelessWidget {
  final ReadingTheme theme;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _LineHeightBtn({required this.theme, required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: isActive ? kGold.withAlpha(30) : Colors.transparent, border: Border.all(color: isActive ? kGold.withAlpha(120) : theme.divider), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, color: isActive ? kGold : theme.text.withAlpha(180))),
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _BottomBtn({required this.icon, required this.label, this.enabled = true, this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: active ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 20, color: active ? kGold : const Color(0xFF5A5040)), const SizedBox(height: 1), Text(label, style: TextStyle(fontSize: 10, color: active ? kGold : const Color(0xFF5A5040)))]),
        ),
      ),
    );
  }
}

class _FontSizeBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ReadingTheme theme;
  const _FontSizeBtn({required this.label, required this.onTap, required this.theme});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: theme.divider), borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.text))));
}

class _ReadingStats extends StatelessWidget {
  final int currentChapter;
  final int totalChapters;
  final double fontSize;
  final double lineHeight;
  final ReadingTheme theme;

  const _ReadingStats({required this.currentChapter, required this.totalChapters, required this.fontSize, required this.lineHeight, required this.theme});

  @override
  Widget build(BuildContext context) {
    final pct = totalChapters > 0 ? (currentChapter / totalChapters * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '进度 $pct% · $currentChapter/$totalChapters 章 · ${fontSize.round()}sp · ${lineHeight.toStringAsFixed(1)}H',
        style: TextStyle(fontSize: 10, color: theme.text.withAlpha(120)),
        textAlign: TextAlign.center,
      ),
    );
  }
}
