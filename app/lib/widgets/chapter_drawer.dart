import 'dart:ui';

import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/ink_loading.dart';
import 'reading_bottom_bar.dart';

// =====================================================================
//  ChapterDrawerItem — 章节信息（供抽屉列表使用）
// =====================================================================

class ChapterDrawerItem {
  final int index;
  final String title;
  const ChapterDrawerItem({required this.index, required this.title});
}

// =====================================================================
//  ChapterDrawer — 左侧章节目录抽屉（毛玻璃效果）
// =====================================================================

class ChapterDrawer extends StatelessWidget {
  final ReadingTheme theme;
  final String bookTitle;
  final List<ChapterDrawerItem> chapters;
  final int currentIndex;
  final void Function(int index) onChapterSelected;

  const ChapterDrawer({
    super.key,
    required this.theme,
    required this.bookTitle,
    required this.chapters,
    required this.currentIndex,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: theme.appBar.withAlpha(170),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.divider),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 36, color: kGold),
                          const SizedBox(height: 12),
                          Text(
                            bookTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.title,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共 ${chapters.length} 章',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.text.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: chapters.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const InkLoading(size: 36),
                                  const SizedBox(height: 12),
                                  Text(
                                    '加载章节列表中...',
                                    style: TextStyle(
                                      color: theme.text.withAlpha(120),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            itemCount: chapters.length,
                            itemBuilder: (context, i) {
                              final ch = chapters[i];
                              final isCurrent = i == currentIndex;
                              return Material(
                                color: isCurrent
                                    ? theme.title.withAlpha(25)
                                    : Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  leading: Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? kGold.withAlpha(180)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: isCurrent
                                          ? null
                                          : Border.all(
                                              color: kGold.withAlpha(60)),
                                    ),
                                    child: Text(
                                      '${ch.index}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isCurrent
                                            ? kPaperDark
                                            : theme.text.withAlpha(180),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    ch.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: isCurrent
                                          ? kGold
                                          : theme.text,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isCurrent
                                      ? Icon(Icons.bookmark_rounded,
                                          size: 18,
                                          color: kGold)
                                      : null,
                                  onTap: () => onChapterSelected(i),
                                ),
                              );
                            },
                          ),
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