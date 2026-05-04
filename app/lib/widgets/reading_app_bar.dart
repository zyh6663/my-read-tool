import 'dart:ui';

import 'package:flutter/material.dart';

import 'reading_bottom_bar.dart'; // ReadingTheme

// =====================================================================
//  ReadingAppBar — 阅读页顶部导航栏（毛玻璃效果）
// =====================================================================

class ReadingAppBar extends StatelessWidget {
  final ReadingTheme theme;
  final String bookTitle;
  final VoidCallback onBackPressed;
  final VoidCallback onFavorite;
  final bool isFavorited;

  const ReadingAppBar({
    super.key,
    required this.theme,
    required this.bookTitle,
    required this.onBackPressed,
    required this.onFavorite,
    required this.isFavorited,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: theme.appBar.withAlpha(160),
            border: Border(
              bottom:
                  BorderSide(color: theme.divider.withAlpha(80), width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: theme.title),
                    onPressed: onBackPressed,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      bookTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.title,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorited ? Icons.favorite : Icons.favorite_border,
                      color: isFavorited ? Colors.red : theme.title,
                    ),
                    onPressed: onFavorite,
                    tooltip: isFavorited ? '已加入书架' : '加入书架',
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