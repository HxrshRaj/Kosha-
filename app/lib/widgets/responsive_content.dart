import 'package:flutter/material.dart';

/// Keeps content readable on wide screens (tablets, foldables) by capping
/// its width and centering it, instead of stretching a phone-designed
/// layout edge-to-edge. Below [breakpoint] it's a no-op passthrough.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double breakpoint;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.breakpoint = 600,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpoint) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
