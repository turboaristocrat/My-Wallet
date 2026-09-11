import 'package:flutter/material.dart';

/// App color palette inspired by modern fintech design (Statok aesthetic)
class AppColors {
  AppColors._();

  // Primary Brand Gradients & Colors (W Wallet Identity)
  static const Color primary = Color(0xFF8B5CF6); // Vibrant Electric Violet
  static const Color primaryDark = Color(0xFF6366F1); // Royal Indigo
  static const Color primaryDarkest = Color(0xFF1E1B4B); // Deepest Midnight
  static const Color primaryLight = Color(0xFFA78BFA); // Soft Lavender Violet
  static const Color primaryContainer = Color(0xFFEDE9FE);

  // Financial Transaction Flow Colors (Neon Accents matching reference)
  static const Color income = Color(0xFF00D2FF); // Electric Cyan for Income
  static const Color incomeGreen = Color(0xFF10B981); // Crisp Emerald
  static const Color incomeContainer = Color(0xFFE0F7FE);
  static const Color expense = Color(0xFFF43F5E); // Neon Pink / Rose for Expense
  static const Color expenseContainer = Color(0xFFFEE2E2);
  static const Color transfer = Color(0xFF8B5CF6); // Electric Violet for Transfer
  static const Color transferContainer = Color(0xFFF3E8FF);
  static const Color investment = Color(0xFFC084FC); // Soft Purple for Investment

  // Warnings & Highlights
  static const Color warning = Color(0xFFFB923C); // Neon Coral / Amber
  static const Color warningContainer = Color(0xFFFFEDD5);
  static const Color info = Color(0xFF38BDF8);
  static const Color aiBadge = Color(0xFFD946EF); // Fuchsia Neon
  static const Color aiBadgeContainer = Color(0xFFFDF4FF);

  // Light Theme Surfaces (Clean Airy Lavender-White)
  static const Color lightBackground = Color(0xFFF4F5FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF1E1B4B); // Midnight navy
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Dark Theme Surfaces (Deep Midnight Indigo & Elevated Purple Panels)
  static const Color darkBackground = Color(0xFF16142E); // Deep Midnight Purple
  static const Color darkCard = Color(0xFF232048); // Elevated Card
  static const Color darkSurface = Color(0xFF262350);
  static const Color darkBorder = Color(0xFF35306B); // Glowing border line
  static const Color darkDivider = Color(0xFF2A2655);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA5B4FC); // Soft lavender
  static const Color darkTextTertiary = Color(0xFF7C77A5);

  // Premium Mesh Card Gradients
  static const LinearGradient cardGradientCyanPurple = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF0072FF), Color(0xFF923CB5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientSunset = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFFB923C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientViolet = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD946EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Bank & Account Accents
  static const List<Color> accountAccents = [
    Color(0xFF00D2FF), // Neon Cyan
    Color(0xFF8B5CF6), // Violet
    Color(0xFFF43F5E), // Rose Pink
    Color(0xFFFB923C), // Coral
    Color(0xFF10B981), // Emerald
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Pink
    Color(0xFFEAB308), // Amber
  ];
}
