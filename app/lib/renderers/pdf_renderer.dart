import 'package:flutter/material.dart';
import '../widgets/reading_bottom_bar.dart';
import 'book_renderer.dart';

/// PDF 鍒嗛〉娓叉煋鍣ㄣ€?
///
/// 鍚庣涓?PDF 姣忎釜椤甸潰杩斿洖涓€鏉＄珷鑺傝褰曪紙index 鍗抽〉鐮侊紝content 鍗宠椤垫枃鏈級锛?
/// 鏈粍浠朵娇鐢?PageView 鎻愪緵宸﹀彸婊戝姩缈婚〉浣撻獙锛岄《閮ㄦ樉绀洪〉鍙锋寚绀哄櫒銆?
class PdfRenderer extends StatefulWidget {
  final List<RendererChapter> chapters;
  final int currentIndex;
  final ReadingTheme theme;
  final double fontSize;
  final double lineHeight;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final ScrollController scrollController;

  const PdfRenderer({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.scrollController,
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
    // 褰撳閮ㄤ紶鍏ョ殑 currentIndex 鍙樺寲鏃讹紝甯﹀姩鐢昏烦杞埌鐩爣椤?
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
        // 椤堕儴椤电爜鎸囩ず鍣?
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
                // 鍚戝乏鍒囨崲绔犺妭鐨勫洖璋冿紙涓婁竴绔犳湯灏?鈫?鍥炲埌涓婁竴椤碉級
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

        // PageView 缈婚〉鍖哄煙
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.chapters.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final page = widget.chapters[index];
              return SingleChildScrollView(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 椤甸潰鏍囬
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
                    // 椤甸潰鍐呭
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