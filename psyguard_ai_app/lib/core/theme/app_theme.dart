import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class LumiTheme {
  // ── Colors (Serene Nature Palette) ────────────────────────────────
  // Sage Green & Warm Sand
  static const Color primary = Color(0xFF0ABFBC); // ERS 綠
  static const Color secondary = Color(0xFF81D4D2); // Warm Sand (Grounding)
  static const Color background = Color(0xFFF8FFFE); // Warm Off-White
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF2D3748); // Slate 800
  static const Color textSecondary = Color(0xFF718096); // Slate 500
  static const Color textLight = Color(0xFFA0AEC0); // Slate 400

  static const Color error = Color(0xFFE57373); // Muted Red
  static const Color success = Color(0xFF81C784); // Muted Green
  static const Color accent = secondary; // Backward compatibility

  // ── Theme Data ────────────────────────────────────────────────────
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        // ignore: deprecated_member_use
        background: background,
        error: error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // Minimalist
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme => theme; // Backward compatibility

  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.varelaRound(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: GoogleFonts.varelaRound(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    displaySmall: GoogleFonts.varelaRound(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleLarge: GoogleFonts.nunitoSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleMedium: GoogleFonts.nunitoSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    bodyLarge: GoogleFonts.nunitoSans(
      fontSize: 16,
      color: textPrimary,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.nunitoSans(
      fontSize: 15,
      color: textSecondary,
      height: 1.5,
    ),
  );

  // ── Decorations ───────────────────────────────────────────────────
  static final BoxDecoration softCard = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0ABFBC).withValues(alpha: 0.08), // Sage shadow
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
    border: Border.all(color: const Color(0xFFF0F0F0)), // Very subtle border
  );

  static final BoxDecoration inputDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE2E8F0)),
  );

  // ── Risk Color Mapping ────────────────────────────────────────────
  static const Color riskLow = Color(0xFF0ABFBC); // Sage (Teal/Green)
  static const Color riskMedium = Color(0xFFE8A838); // Warm Orange
  static const Color riskHigh = Color(0xFFD14343); // Deep Red

  /// 根據風險分數 (0-100) 回傳對應顏色。
  /// 0-40 → 藍綠 / 41-70 → 橘 / 71+ → 深紅
  static Color riskColor(int score) {
    if (score <= 40) return riskLow;
    if (score <= 70) return riskMedium;
    return riskHigh;
  }

  // ── 負面關鍵字 (用於 Bold Logic) ──────────────────────────────────
  static const List<String> negativeKeywords = [
    '累',
    '痛',
    '壓力',
    '焦慮',
    '害怕',
    '難過',
    '絕望',
    '孤單',
    '沮喪',
    '生氣',
    '崩潰',
    '撐不住',
    '不想',
    '無助',
    '失眠',
    '疲憊',
    '煩',
    '哭',
    '受傷',
    '恐慌',
  ];
}
