import 'package:flutter/material.dart';

/// Type scale used across the app. Defined once so every screen shares the
/// same heading/body/label rhythm instead of picking font sizes ad hoc.
abstract final class AppTextStyles {
  static const _base = TextStyle(fontFamily: 'Roboto', height: 1.3);

  static final displayLg = _base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
  );
  static final headline = _base.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );
  static final title = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
  static final body = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w400);
  static final bodyStrong = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static final caption = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
  static final overline = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );
  static final amountLg = _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );
}
