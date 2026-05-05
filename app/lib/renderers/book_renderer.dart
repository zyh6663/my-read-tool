import 'package:flutter/material.dart';
import '../widgets/reading_bottom_bar.dart';
import 'flow_text_renderer.dart';
import 'pdf_renderer.dart';
import 'txt_renderer.dart';

/// 支持的书籍格式枚举
enum BookFormat {
  txt,
  epub,
  pdf,
  mobi,
  unknown,
}

/// 根据文件扩展名字符串推断格式
BookFormat bookFormatFromString(String? format) {
  if (format == null || format.isEmpty) return BookFormat.unknown;
  switch (format.toLowerCase().trim()) {
    case 'txt':
      return BookFormat.txt;
    case 'epub':
      return BookFormat.epub;
    case 'pdf':
      return BookFormat.pdf;
    case 'mobi':
      return BookFormat.mobi;
    default:
      return BookFormat.unknown;
  }
}

/// 渲染器使用的章节数据模型（与 reading_page.dart 解耦）
class RendererChapter {
  final int index;
  final String title;
  final String content;
  const RendererChapter({
    required this.index,
    required this.title,
    required this.content,
  });
}

/// 根据 BookFormat 返回对应的渲染组件。
///
/// [format]    当前书籍的格式
/// [chapters]  章节列表（每章包含 index / title / content）
/// [currentIndex] 当前阅读到的章节索引
/// [theme]     阅读主题配置
/// [fontSize]  正文字号
/// [lineHeight] 行高
/// [onPrevChapter] 上一章回调
/// [onNextChapter] 下一章回调
Widget buildBookRenderer({
  required BookFormat format,
  required List<RendererChapter> chapters,
  required int currentIndex,
  required ReadingTheme theme,
  required double fontSize,
  required double lineHeight,
  required VoidCallback onPrevChapter,
  required VoidCallback onNextChapter,
}) {
  switch (format) {
    case BookFormat.epub:
    case BookFormat.mobi:
      return FlowTextRenderer(
        chapters: chapters,
        currentIndex: currentIndex,
        theme: theme,
        fontSize: fontSize,
        lineHeight: lineHeight,
      );
    case BookFormat.pdf:
      return PdfRenderer(
        chapters: chapters,
        currentIndex: currentIndex,
        theme: theme,
        fontSize: fontSize,
        lineHeight: lineHeight,
        onPrevChapter: onPrevChapter,
        onNextChapter: onNextChapter,
      );
    case BookFormat.txt:
    case BookFormat.unknown:
    default:
      return TxtRenderer(
        chapters: chapters,
        currentIndex: currentIndex,
        theme: theme,
        fontSize: fontSize,
        lineHeight: lineHeight,
      );
  }
}