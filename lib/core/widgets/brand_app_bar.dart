import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';

import 'package:lpco_llc/core/navigation/app_back_navigation.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/core/widgets/lpco_logo.dart';
import 'package:lpco_llc/core/widgets/glass.dart';

class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double toolbarHeightValue = 62;

  final String? title;
  final bool showMenu;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  const BrandAppBar({
    super.key,
    this.title,
    this.showMenu = false,
    this.showBack = false,
    this.onBack,
    this.actions = const <Widget>[],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: toolbarHeightValue,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              border: Border(
                bottom: BorderSide(color: const Color(0xFFE7EBF2), width: 1),
              ),
            ),
          ),
        ),
      ),
      leadingWidth: 52,
      leading: showMenu
          ? Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () {
                    final zoomDrawer = ZoomDrawer.of(context);
                    if (zoomDrawer != null) {
                      zoomDrawer.toggle();
                      return;
                    }
                    Scaffold.of(context).openDrawer();
                  },
                );
              },
            )
          : showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack ?? () => AppBackNavigation.popOrGo(context),
            )
          : null,
      title: title == null
          ? const LpcoLogo(showTagline: false, fontSize: 30)
          : Text(
              TextSanitizer.fix(title!),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 21,
                color: GlassStyle.darkText,
              ),
            ),
      centerTitle: true,
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    bottom == null
        ? toolbarHeightValue
        : toolbarHeightValue + bottom!.preferredSize.height,
  );
}
