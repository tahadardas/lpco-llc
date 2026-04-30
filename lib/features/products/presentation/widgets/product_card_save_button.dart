import 'package:flutter/material.dart';

class ProductCardSaveButton extends StatelessWidget {
  final bool compact;
  final bool isSaved;
  final VoidCallback onPressed;

  const ProductCardSaveButton({
    super.key,
    required this.compact,
    required this.isSaved,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = compact;
    return SizedBox(
      width: isCompact ? 36 : 34,
      height: isCompact ? 36 : 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: isCompact ? Colors.white : const Color(0xFFF4F6FA),
          foregroundColor: isSaved
              ? const Color(0xFFD31225)
              : const Color(0xFF5E6675),
          shape: isCompact
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: isCompact ? 1.2 : 0,
        ),
        onPressed: onPressed,
        icon: Icon(
          isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: isCompact ? 20 : 20,
        ),
      ),
    );
  }
}
