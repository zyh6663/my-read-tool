import 'package:flutter/material.dart';
import '../widgets/reading_bottom_bar.dart';

/// PDF 分页渲染器。
///
/// 后端为 PDF 每个页面返回一条章节记录（index 即页码，content 即该页文本），
/// 本组件使用 PageView 提供左右滑动翻页体验，顶部显示页号指示器。
class PdfRenderer extends StatefulWidget {
  final List<RendererChapter> chapters;
  final int currentIndex;
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;

  const PdfRenderer({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.onPrevChapter,
    required this.onNextChapter,
  });

  @override
  State<PdfRenderer> createState() => _PdfRendererState();
}

class _PdfRendererState extends State<PdfRenderer> {
  late PageController _pageController;
  int _displayedPage = 0;

  @override
  void initState() {
    super.initState();
    _displayedPage = widget.currentIndex.clamp(0,
        widget.chapters.isEmpty ? 0 : widget.chapters.length - 1);
    _pageController = PageController(initialPage: _displayedPage);
  }

  @override
  void didUpdateWidget(covariant PdfRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部传入的 currentIndex 变化时，带动画跳转到目标页
    if (oldWidget.currentIndex != widget.currentIndex) {
      final target = widget.currentIndex.clamp(0,
          widget.chapters.isEmpty ? 0 : widget.chapters.length - 1);
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _displayedPage = target);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return Center(
        child: Text(
          '暂无内容',
          style: TextStyle(color: widget.theme.text, fontSize: widget.fontSize),
        ),
      );
    }

    final safeIndex = _displayedPage.clamp(
        0, widget.chapters.length - 1);

    return Column(
      children: [
        // 顶部页码指示器
        SafeArea(
          bottom: false,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: widget.theme.background.withAlpha(180),
            child: Row(
              children: [
                Text(
                  '第 ${safeIndex + 1} 页 / 共 ${widget.chapters.length} 页',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.theme.text.withAlpha(150),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // 向左切换章节的回调（上一章末尾 → 回到上一页）
                IconButton(
                  icon: Icon(Icons.chevron_left,
                      size: 20, color: widget.theme.text),
                  tooltip: '上一页',
                  onPressed: safeIndex > 0 ? _goToPreviousPage : widget.onPrevChapter,
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      size: 20, color: widget.theme.text),
                  tooltip: '下一页',
                  onPressed: safeIndex < widget.chapters.length - 1
                      ? _goToNextPage
                      : widget.onNextChapter,
                ),
              ],
            ),
          ),
        ),

        // PageView 翻页区域
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.chapters.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final page = widget.chapters[index];
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 页面标题
                    if (page.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          page.title,
                          style: TextStyle(
                            fontSize: widget.fontSize * 1.1,
                            fontWeight: FontWeight.w700,
                            color: widget.theme.title,
                            height: widget.lineHeight,
                          ),
                        ),
                      ),
                    // 页面内容
                    SelectableText(
                      page.content,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        height: widget.lineHeight,
                        color: widget.theme.text,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _onPageChanged(int page) {
    setState(() => _displayedPage = page);
  }

  void _goToPreviousPage() {
    final prev = _displayedPage - 1;
    if (prev >= 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _displayedPage = prev);
    }
  }

  void _goToNextPage() {
    final next = _displayedPage + 1;
    if (next < widget.chapters.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _displayedPage = next);
    }
  }
}