import 'package:flutter/material.dart';

/// Common typography, card styles, and border radius tokens
class AppStyles {
  AppStyles._();

  // Radii
  static const double radiusS = 8.0;
  static const double radiusM = 14.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 28.0;

  static final BorderRadius roundedS = BorderRadius.circular(radiusS);
  static final BorderRadius roundedM = BorderRadius.circular(radiusM);
  static final BorderRadius roundedL = BorderRadius.circular(radiusL);
  static final BorderRadius roundedXL = BorderRadius.circular(radiusXL);

  // Soft Ambient Box Shadows (W Wallet reference styling)
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 20,
      offset: Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> heroGlowShadow = [
    BoxShadow(
      color: Color(0x3D6366F1), // Royal Indigo glow
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> cyanGlowShadow = [
    BoxShadow(
      color: Color(0x3300C6FF), // Cyan glow
      blurRadius: 20,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // Text Styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
}
