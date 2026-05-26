import 'dart:ui';

import 'package:flutter/material.dart';

import '../main.dart';
import 'reading_bottom_bar.dart';

class ReadingAppBar extends StatelessWidget {
  final ReadingTheme theme;
  final String bookTitle;
  final VoidCallback onBackPressed;
  final VoidCallback onFavorite;
  final bool isFavorited;
  final VoidCallback onToggleImmersive;
  final bool isImmersive;
  final VoidCallback onDownload;
  final VoidCallback onBookmark;

  const ReadingAppBar({
    super.key,
    required this.theme,
    required this.bookTitle,
    required this.onBackPressed,
    required this.onFavorite,
    required this.isFavorited,
    required this.onToggleImmersive,
    required this.isImmersive,
    required this.onDownload,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: theme.appBar.withAlpha(230),
            border: Border(
              bottom: BorderSide(color: kGold.withAlpha(60), width: 0.6),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _IconGlassButton(
                    icon: Icons.arrow_back_rounded,
                    color: kGold,
                    onTap: onBackPressed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bookTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kInkWarm),
                    ),
                  ),
                  _IconGlassButton(
                    icon: isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorited ? kVermilion : kGold,
                    onTap: onFavorite,
                  ),
                  _IconGlassButton(
                    icon: Icons.bookmark_add_rounded,
                    color: kGold,
                    onTap: onBookmark,
                  ),
                  IconButton(
                    icon: Icon(isImmersive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: theme.text.withAlpha(180)),
                    tooltip: isImmersive ? '退出沉浸' : '沉浸模式',
                    onPressed: onToggleImmersive,
                  ),
                  IconButton(
                    icon: Icon(Icons.download_rounded, color: theme.text.withAlpha(180)),
                    tooltip: '下载全书',
                    onPressed: onDownload,
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

class _IconGlassButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconGlassButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPaperDark.withAlpha(80),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kGold.withAlpha(30)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
