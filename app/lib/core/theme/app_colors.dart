import 'package:flutter/material.dart';

/// Single source of truth for every color used in the app. Screens and
/// widgets reference these tokens instead of hardcoding hex values, so the
/// palette can change in one place and stay consistent everywhere.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4B44CC);
  static const onPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const income = Color(0xFF2ECC71);
  static const expense = Color(0xFFFF6B6B);
  static const warning = Color(0xFFF7B733);

  // Light surface scale
  static const backgroundLight = Color(0xFFF7F7FB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF0F0F7);
  static const borderLight = Color(0xFFE4E4EF);
  static const textPrimaryLight = Color(0xFF1A1B25);
  static const textSecondaryLight = Color(0xFF6E6F80);

  // Dark surface scale
  static const backgroundDark = Color(0xFF121218);
  static const surfaceDark = Color(0xFF1C1C25);
  static const surfaceAltDark = Color(0xFF25252F);
  static const borderDark = Color(0xFF33333F);
  static const textPrimaryDark = Color(0xFFF2F2F7);
  static const textSecondaryDark = Color(0xFFA3A4B5);

  // Category palette (also used by the backend seed data as defaults)
  static const categoryPalette = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFF4D96FF),
    Color(0xFFF7B733),
    Color(0xFF6C63FF),
    Color(0xFF00C2A8),
    Color(0xFFFF8FB1),
    Color(0xFF2ECC71),
    Color(0xFFA0A0A0),
  ];
}
