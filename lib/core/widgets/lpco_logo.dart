import 'dart:math' as math;

import 'package:flutter/material.dart';

class LpcoLogo extends StatefulWidget {
  final bool showTagline;
  final double fontSize;

  const LpcoLogo({super.key, this.showTagline = true, this.fontSize = 34});

  @override
  State<LpcoLogo> createState() => _LpcoLogoState();
}

class _LpcoLogoState extends State<LpcoLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoHeight = widget.fontSize + 10;
    final logoWidth = widget.fontSize * 2.2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        final scale = 1 + (math.sin(t) * 0.025);
        final dy = math.sin(t) * -2.0;
        final rotation = math.sin(t) * 0.02;
        final glow = 0.18 + ((math.sin(t) + 1) * 0.07);

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFD31225,
                          ).withValues(alpha: glow),
                          blurRadius: 16,
                          spreadRadius: 0.6,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: logoHeight,
                        width: logoWidth,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  if (widget.showTagline)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'LPCO LLC',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF5F6672),
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
