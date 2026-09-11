import 'package:flutter/material.dart';

/// App color palette inspired by modern fintech design (Statok aesthetic)
class AppColors {
  AppColors._();

  // Primary Emerald Brand Colors
  static const Color primary = Color(0xFF008080); // Classic deep teal
  static const Color primaryDark = Color(0xFF064E3B); // Deep emerald hero
  static const Color primaryDarkest = Color(0xFF042F2E);
  static const Color primaryLight = Color(0xFF26B2AB); // Vibrant mint teal
  static const Color primaryContainer = Color(0xFFE6F4F2);

  // Financial Transaction Flow Colors
  static const Color income = Color(0xFF10B981); // Emerald green for Income
  static const Color incomeContainer = Color(0xFFE6F9F2);
  static const Color expense = Color(0xFFEF4444); // Crimson red for Expense
  static const Color expenseContainer = Color(0xFFFEE2E2);
  static const Color transfer = Color(0xFF2563EB); // Sapphire blue for Transfer
  static const Color transferContainer = Color(0xFFEFF6FF);

  // Warnings & Highlights
  static const Color warning = Color(0xFFF59E0B); // Amber for 80% budget alert
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF0EA5E9);
  static const Color aiBadge = Color(0xFF8B5CF6); // Violet for AI sparkle badges
  static const Color aiBadgeContainer = Color(0xFFF5F3FF);

  // Light Theme Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC); // Cool slate white
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFEEF2F6);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF0B1120); // Rich obsidian navy
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Bank & Account Accents
  static const List<Color> accountAccents = [
    Color(0xFF008080), // Teal
    Color(0xFF2563EB), // Blue (HDFC-style)
    Color(0xFFEA580C), // Orange (ICICI-style)
    Color(0xFF16A34A), // Green (SBI-style)
    Color(0xFF9333EA), // Purple (Axis-style)
    Color(0xFF0284C7), // Sky Blue (Paytm-style)
    Color(0xFFE11D48), // Rose Red (Kotak-style)
    Color(0xFFD97706), // Amber
  ];
}
