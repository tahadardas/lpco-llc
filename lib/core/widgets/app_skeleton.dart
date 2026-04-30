import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AppSkeleton extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const AppSkeleton({super.key, required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: enabled,
      effect: const ShimmerEffect(
        baseColor: Color(0xFFE7EBF1),
        highlightColor: Color(0xFFF7F9FC),
        duration: Duration(milliseconds: 1100),
      ),
      child: child,
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE7EBF1),
        borderRadius: borderRadius,
      ),
    );
  }
}
