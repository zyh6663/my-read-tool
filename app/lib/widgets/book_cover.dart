import 'package:flutter/material.dart';

import '../main.dart';

Color _dynamicColor(String title) {
  if (title.isEmpty) return kPaperWarm;
  final hash = title.codeUnits.fold(0, (v, c) => v * 31 + c).abs();
  return Color.fromARGB(220, 80 + hash % 80, 50 + (hash >> 8) % 90, 40 + (hash >> 16) % 100);
}

class BookCover extends StatelessWidget {
  final String title;
  final String? author;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool verticalTitle;

  const BookCover({
    super.key,
    required this.title,
    this.author,
    this.onTap,
    this.width = 120,
    this.height = 170,
    this.verticalTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _dynamicColor(title),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(color: kGold.withAlpha(25), blurRadius: 8, offset: const Offset(2, 4)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: kGold.withAlpha(100),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            ),
            ClipPath(
              clipper: _FoldClipper(),
              child: Container(
                decoration: BoxDecoration(
                  color: kPaperDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                width: 18,
                height: 18,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8, top: 16, bottom: 12),
              child: verticalTitle
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: title.split('').map((c) => Text(c, style: const TextStyle(fontSize: 13, color: kInkWarm, fontWeight: FontWeight.w600))).toList(),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInkWarm)),
                        if (author != null && author!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: kInkGray)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
