import 'dart:ui';

import 'package:flutter/material.dart';

import 'reading_bottom_bar.dart';

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
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.appBar.withAlpha(190),
                theme.appBar.withAlpha(150),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(color: theme.divider.withAlpha(90), width: 0.6),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _IconGlassButton(icon: Icons.arrow_back_rounded, color: theme.title, onTap: onBackPressed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bookTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.title),
                    ),
                  ),
                  _IconGlassButton(
                    icon: isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: isFavorited ? Colors.redAccent : theme.title,
                    onTap: onFavorite,
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
