import 'package:flutter/material.dart';

/// Shared semantic colors for custom surfaces, matching the active Material theme.
class AppColors {
  const AppColors._(this.isDark);
  final bool isDark;
  static const light = AppColors._(false);
  static const dark = AppColors._(true);

  Color get ink => isDark ? const Color(0xFFE6EDF7) : const Color(0xFF1F2937);
  Color get muted => isDark ? const Color(0xFFA5B2C5) : const Color(0xFF657184);
  Color get blue => isDark ? const Color(0xFF9FC2FF) : const Color(0xFF185ABC);
  Color get onBlue =>
      isDark ? const Color(0xFF102A50) : const Color(0xFFFFFFFF);
  Color get canvas =>
      isDark ? const Color(0xFF0F141D) : const Color(0xFFF6F8FC);
  Color get outline =>
      isDark ? const Color(0xFF344256) : const Color(0xFFE3E8F0);
  Color get panel => isDark ? const Color(0xFF171F2B) : const Color(0xFFFFFFFF);
  Color get raisedPanel =>
      isDark ? const Color(0xFF1D2838) : const Color(0xFFFFFFFF);
  Color get insetPanel =>
      isDark ? const Color(0xFF121A26) : const Color(0xFFF8FAFD);
  Color get selectPanel =>
      isDark ? const Color(0xFF121A26) : const Color(0xFFFFFFFF);
  Color get tablePanel =>
      isDark ? const Color(0xFF121A26) : const Color(0xFFFBFCFE);
  Color get iconPanel =>
      isDark ? const Color(0xFF1D2838) : const Color(0xFFF0F4FA);
  Color get emptyPanel =>
      isDark ? const Color(0xFF223654) : const Color(0xFFEAF0FC);
  Color get blueContainer =>
      isDark ? const Color(0xFF223654) : const Color(0xFFE8F0FE);
  Color get selectedSurface =>
      isDark ? const Color(0xFF2B4163) : const Color(0xFFDDE8FC);
  Color get success =>
      isDark ? const Color(0xFF86D7AA) : const Color(0xFF146C43);
  Color get successContainer =>
      isDark ? const Color(0xFF193C30) : const Color(0xFFE6F4EA);
  Color get warning =>
      isDark ? const Color(0xFFF1CC7C) : const Color(0xFF8F6000);
  Color get warningContainer =>
      isDark ? const Color(0xFF44351C) : const Color(0xFFFEF3D6);
  Color get purple =>
      isDark ? const Color(0xFFC6ACF0) : const Color(0xFF7954AC);
  Color get purpleContainer =>
      isDark ? const Color(0xFF342944) : const Color(0xFFF0EAFB);
  Color get danger =>
      isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E);
  Color get dangerContainer =>
      isDark ? const Color(0xFF542723) : const Color(0xFFF9DEDC);
  Color get onDanger =>
      isDark ? const Color(0xFF561E19) : const Color(0xFFFFFFFF);
  Color get menuBorder =>
      isDark ? const Color(0xFF344256) : const Color(0xFFDDE1E7);
  Color get menuHighlight =>
      isDark ? const Color(0xFF2C3747) : const Color(0xFFF1F3F5);
}

extension SecretPodColors on BuildContext {
  AppColors get colors => Theme.of(this).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
}
