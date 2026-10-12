import 'package:flutter/material.dart';

/// Pokémon-inspired classroom palette: Poké Ball red, electric yellow,
/// adventure blue, and high-contrast trainer navy.
class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFFE33535);
  static const Color primaryLight = Color(0xFFFF7474);
  static const Color primaryDark = Color(0xFFB71C2A);

  // Secondary palette
  static const Color secondary = Color(0xFFFFCB05);
  static const Color secondaryLight = Color(0xFFFFE16A);
  static const Color secondaryDark = Color(0xFFD19F00);

  // Accent colors
  static const Color accent = Color(0xFF2A75BB);
  static const Color accentLight = Color(0xFF72B9F2);

  // Background
  static const Color background = Color(0xFFF2F7FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE7EFF8);

  // Text
  static const Color textPrimary = Color(0xFF172A46);
  static const Color textSecondary = Color(0xFF50647E);
  static const Color textLight = Color(0xFFFFFFFF);

  // Feedback colors
  static const Color correct = Color(0xFF66BB6A);
  static const Color incorrect = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFA726);

  // Star colors
  static const Color starFilled = Color(0xFFFFD600);
  static const Color starEmpty = Color(0xFFE0E0E0);

  // Finger color zones for keyboard (color-coded by finger)
  static const Color fingerPinkyLeft = Color(0xFFE57373); // Red
  static const Color fingerRingLeft = Color(0xFFFFB74D); // Orange
  static const Color fingerMiddleLeft = Color(0xFFFFD54F); // Yellow
  static const Color fingerIndexLeft = Color(0xFF81C784); // Green
  static const Color fingerIndexRight = Color(0xFF4FC3F7); // Light blue
  static const Color fingerMiddleRight = Color(0xFF7986CB); // Indigo
  static const Color fingerRingRight = Color(0xFFBA68C8); // Purple
  static const Color fingerPinkyRight = Color(0xFFF06292); // Pink
  static const Color fingerThumb = Color(0xFF90A4AE); // Gray-blue

  // Lesson category colors
  static const Color categoryHomeRow = Color(0xFF66BB6A);
  static const Color categoryTopRow = Color(0xFF42A5F5);
  static const Color categoryBottomRow = Color(0xFFAB47BC);
  static const Color categoryNumbers = Color(0xFFFF7043);
  static const Color categoryWords = Color(0xFFEC407A);
  static const Color categorySentences = Color(0xFF26C6DA);
}
