// lib/widgets/slide_page_route.dart
import 'package:flutter/material.dart';

/// Simple right-to-left slide + fade push transition, used for screens
/// pushed outside the bottom nav (e.g. Notifications) so navigation feels
/// consistent across platforms instead of relying on OS-default transitions.
Route<T> slidePageRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetTween = Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(offsetTween),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 260),
  );
}
