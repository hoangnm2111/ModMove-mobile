import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Customer and authentication surfaces share the approved Driver palette.
/// Kept separate so driver screens retain their tested density and sizing.
ThemeData buildCustomerTheme() {
  final base = buildAppTheme();
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.pale,
    colorScheme: base.colorScheme.copyWith(
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.secondary,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
    ),
    iconTheme: const IconThemeData(color: AppColors.ink),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.orange
            : AppColors.line,
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: AppColors.pale,
      titleTextStyle: appText(size: 20, weight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: shape,
        textStyle: appText(size: 16, weight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        foregroundColor: AppColors.orange,
        side: const BorderSide(color: AppColors.orange),
        shape: shape,
        textStyle: appText(size: 15, weight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        textStyle: appText(size: 14, weight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: appText(color: AppColors.muted),
      labelStyle: appText(color: AppColors.secondary),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.orange, 1.5),
      errorBorder: border(AppColors.red),
      focusedErrorBorder: border(AppColors.red, 1.5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 76,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => appText(
          size: 12,
          weight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? AppColors.orange
              : AppColors.secondary,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: AppColors.ink,
      titleTextStyle: appText(size: 15, weight: FontWeight.w600),
      subtitleTextStyle: appText(size: 12, color: AppColors.secondary),
    ),
  );
}
