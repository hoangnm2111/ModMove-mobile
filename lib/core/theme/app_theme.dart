import 'package:flutter/material.dart';

abstract final class AppColors {
  static const orange = Color(0xFFD94B18);
  static const ink = Color(0xFF151B24);
  static const secondary = Color(0xFF606875);
  static const muted = Color(0xFF858C99);
  static const line = Color(0xFFE6E8EC);
  static const peach = Color(0xFFFFF1E8);
  static const pale = Color(0xFFF5F6F8);
  static const green = Color(0xFF159347);
  static const greenBg = Color(0xFFE6F5EA);
  static const amber = Color(0xFFE99300);
  static const amberBg = Color(0xFFFFF4E1);
  static const red = Color(0xFFD9232C);
  static const redBg = Color(0xFFFFECEE);
}

TextStyle appText({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double height = 1.35,
  double spacing = -0.3,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: spacing,
);

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.orange,
    primary: AppColors.orange,
    surface: Colors.white,
  ),
  textTheme: TextTheme(
    bodyMedium: appText(),
    bodyLarge: appText(size: 16),
    titleLarge: appText(size: 20, weight: FontWeight.w700),
    titleMedium: appText(size: 16, weight: FontWeight.w700),
    labelLarge: appText(size: 14, weight: FontWeight.w600),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.orange
            : AppColors.pale,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.ink,
      ),
      textStyle: WidgetStatePropertyAll(
        appText(size: 13, weight: FontWeight.w600),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 46),
      foregroundColor: AppColors.orange,
      side: const BorderSide(color: AppColors.orange),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: appText(size: 18, weight: FontWeight.w700),
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    hintStyle: appText(color: AppColors.muted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: Color(0xFFD2D6DE)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: Color(0xFFD2D6DE)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
    ),
  ),
);
