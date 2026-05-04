import 'dart:ui';

import 'package:flutter/material.dart';

// =====================================================================
//  ReadingTheme — 阅读主题定义（从 reading_page.dart 抽出）
// =====================================================================

class ReadingTheme {
  final Color background;
  final Color text;
  final Color title;
  final Color appBar;
  final Color divider;
  final String label;

  const ReadingTheme({
    required this.background,
    required this.text,
    required this.title,
    required this.appBar,
    required this.divider,
    required this.label,
  });

  static const eyeCare = ReadingTheme(
    background: Color(0xFFFFF8E1),
    text: Color(0xFF5A5A5A),
    title: Color(0xFF3E3232),
    appBar: Color(0xFFFFF8E1),
    divider: Color(0xFFE8DCC8),
    label: '护眼',
  );

  static const dark = ReadingTheme(
    background: Color(0xFF1E1E1E),
    text: Color(0xFFCCCCCC),
    title: Color(0xFFDDDDDD),
    appBar: Color(0xFF1E1E1E),
    divider: Color(0xFF333333),
    label: '暗黑',
  );

  static const parchment = ReadingTheme(
    background: Color(0xFFF0E6D3),
    text: Color(0xFF4A4A4A),
    title: Color(0xFF3E3232),
    appBar: Color(0xFFF0E6D3),
    divider: Color(0xFFD8CEB8),
    label: '羊皮纸',
  );
}

// =====================================================================
//  ReadingBottomBar — 底部设置控制台（毛玻璃效果）
// =====================================================================

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

  const ReadingBottomBar({
    super.key,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: theme.appBar.withAlpha(170),
            border: Border(
              top: BorderSide(color: theme.divider.withAlpha(80), width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CustomizeRow(
                    theme: theme,
                    fontSize: fontSize,
                    lineHeight: lineHeight,
                    onThemeChanged: onThemeChanged,
                    onFontSizeChanged: onFontSizeChanged,
                    onLineHeightChanged: onLineHeightChanged,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _BottomBtn(
                        icon: Icons.skip_previous_rounded,
                        label: '上一章',
                        enabled: currentChapterIndex > 0,
                        onTap: currentChapterIndex > 0 ? onPrevChapter : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${currentChapterIndex + 1} / $totalChapters',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.text,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _BottomBtn(
                        icon: Icons.skip_next_rounded,
                        label: '下一章',
                        enabled: currentChapterIndex < totalChapters - 1,
                        onTap: currentChapterIndex < totalChapters - 1
                            ? onNextChapter
                            : null,
                      ),
                      const Spacer(),
                      _BottomBtn(
                        icon: Icons.list_rounded,
                        label: '目录',
                        enabled: true,
                        onTap: onOpenDrawer,
                      ),
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

// =====================================================================
//  _CustomizeRow — 主题 / 字体 / 行距 自定义
// =====================================================================

class _CustomizeRow extends StatelessWidget {
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;
  final ValueChanged<ReadingTheme> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;

  const _CustomizeRow({
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    const themes = [
      ReadingTheme.eyeCare,
      ReadingTheme.dark,
      ReadingTheme.parchment,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              ...themes.map((t) {
                final isActive = t == theme;
                return GestureDetector(
                  onTap: () => onThemeChanged(t),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: t.background,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? theme.title : t.divider,
                        width: isActive ? 2.5 : 1.5,
                      ),
                    ),
                    child: isActive
                        ? Icon(Icons.check, size: 14, color: theme.text)
                        : null,
                  ),
                );
              }),
              const SizedBox(width: 12),
              Container(width: 1, height: 20, color: theme.divider),
              const SizedBox(width: 12),
              _FontSizeBtn(
                label: 'A-',
                onTap: () => onFontSizeChanged(
                    (fontSize - 1).clamp(12.0, 30.0)),
                theme: theme,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.title.withAlpha(150),
                    inactiveTrackColor: theme.divider,
                    thumbColor: theme.title,
                    overlayColor: theme.title.withAlpha(20),
                    trackHeight: 2.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: fontSize,
                    min: 12,
                    max: 30,
                    divisions: 18,
                    label: '${fontSize.round()}',
                    onChanged: onFontSizeChanged,
                  ),
                ),
              ),
              _FontSizeBtn(
                label: 'A+',
                onTap: () => onFontSizeChanged(
                    (fontSize + 1).clamp(12.0, 30.0)),
                theme: theme,
              ),
              SizedBox(
                width: 30,
                child: Text(
                  '${fontSize.round()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.text.withAlpha(180),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: Row(
            children: [
              Text('行距',
                  style: TextStyle(
                      fontSize: 11, color: theme.text.withAlpha(150))),
              const SizedBox(width: 6),
              _LineHeightBtn(
                theme: theme,
                value: 1.2,
                label: '紧凑',
                isActive: (lineHeight - 1.2).abs() < 0.01,
                onTap: () => onLineHeightChanged(1.2),
              ),
              const SizedBox(width: 4),
              _LineHeightBtn(
                theme: theme,
                value: 1.5,
                label: '标准',
                isActive: (lineHeight - 1.5).abs() < 0.01,
                onTap: () => onLineHeightChanged(1.5),
              ),
              const SizedBox(width: 4),
              _LineHeightBtn(
                theme: theme,
                value: 1.8,
                label: '宽松',
                isActive: (lineHeight - 1.8).abs() < 0.01,
                onTap: () => onLineHeightChanged(1.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.title.withAlpha(150),
                    inactiveTrackColor: theme.divider,
                    thumbColor: theme.title,
                    overlayColor: theme.title.withAlpha(20),
                    trackHeight: 2.0,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(
                    value: lineHeight,
                    min: 1.0,
                    max: 2.0,
                    divisions: 20,
                    label: lineHeight.toStringAsFixed(1),
                    onChanged: onLineHeightChanged,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  lineHeight.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: theme.text.withAlpha(180)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
//  _LineHeightBtn
// =====================================================================

class _LineHeightBtn extends StatelessWidget {
  final ReadingTheme theme;
  final double value;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LineHeightBtn({
    required this.theme,
    required this.value,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? theme.title.withAlpha(30) : Colors.transparent,
          border: Border.all(
            color: isActive ? theme.title.withAlpha(120) : theme.divider,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? theme.title : theme.text.withAlpha(180),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  _BottomBtn
// =====================================================================

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _BottomBtn({
    required this.icon,
    required this.label,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isActive ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.grey[700] : Colors.grey[350],
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.grey[600] : Colors.grey[350],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  _FontSizeBtn
// =====================================================================

class _FontSizeBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ReadingTheme theme;

  const _FontSizeBtn({
    required this.label,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.text,
          ),
        ),
      ),
    );
  }
}