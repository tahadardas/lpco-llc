import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/network_cubit.dart';
import 'package:lpco_llc/core/theme/app_animations.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class NetworkBannerWrapper extends StatefulWidget {
  final Widget child;

  const NetworkBannerWrapper({super.key, required this.child});

  @override
  State<NetworkBannerWrapper> createState() => _NetworkBannerWrapperState();
}

class _NetworkBannerWrapperState extends State<NetworkBannerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  Timer? _hideTimer;
  String _bannerMessage = '';
  Color _bannerColor = Colors.transparent;
  bool _isOffline = false;
  bool _isBannerVisible = false;

  void _applyBannerState({required String message, required Color color}) {
    if (!mounted) {
      return;
    }

    void update() {
      if (!mounted) {
        return;
      }
      setState(() {
        _bannerMessage = TextSanitizer.fix(message);
        _bannerColor = color;
      });
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      update();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => update());
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.normal,
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() {
          _isBannerVisible = false;
          _bannerMessage = '';
          _bannerColor = Colors.transparent;
        });
      }
    });
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppAnimations.smooth,
          ),
        );
  }

  void _showTimedBanner({
    required String message,
    required Color color,
    Duration duration = const Duration(seconds: 2),
  }) {
    _hideTimer?.cancel();
    _applyBannerState(message: message, color: color);
    if (mounted) {
      setState(() {
        _isBannerVisible = true;
      });
      _animationController.forward(from: 0);
    }

    _hideTimer = Timer(duration, () {
      if (mounted) {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NetworkCubit, NetworkStatus>(
      listener: (context, state) {
        if (state == NetworkStatus.offline) {
          if (_isOffline) {
            return;
          }
          _isOffline = true;
          _showTimedBanner(
            message: 'انقطع الاتصال بالإنترنت',
            color: const Color(0xFFD31225),
          );
          return;
        }

        if (state == NetworkStatus.online) {
          if (!_isOffline) {
            return;
          }
          _isOffline = false;
          _showTimedBanner(
            message: 'تمت استعادة الاتصال بالإنترنت',
            color: const Color(0xFF1B8E4B),
          );
        }
      },
      child: Stack(
        children: <Widget>[
          widget.child,
          if (_isBannerVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: true,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Material(
                        color: _bannerColor,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            TextSanitizer.fix(_bannerMessage),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
