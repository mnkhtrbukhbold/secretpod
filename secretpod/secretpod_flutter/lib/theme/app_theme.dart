import 'package:flutter/material.dart';
import '../widgets/dropdown_field.dart';
import 'app_colors.dart';

ThemeData secretPodTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: brightness == Brightness.light
        ? ColorScheme.fromSeed(seedColor: colors.blue, surface: colors.panel)
        : ColorScheme.fromSeed(
            seedColor: colors.blue,
            brightness: brightness,
            primary: colors.blue,
            onPrimary: colors.onBlue,
            primaryContainer: colors.blueContainer,
            onPrimaryContainer: colors.ink,
            secondary: colors.blue,
            onSecondary: colors.onBlue,
            secondaryContainer: colors.selectedSurface,
            onSecondaryContainer: colors.ink,
            tertiary: colors.purple,
            onTertiary: colors.purpleContainer,
            tertiaryContainer: colors.purpleContainer,
            onTertiaryContainer: colors.purple,
            surface: colors.panel,
            onSurface: colors.ink,
            onSurfaceVariant: colors.muted,
            surfaceDim: colors.canvas,
            surfaceBright: colors.raisedPanel,
            surfaceContainerLowest: colors.canvas,
            surfaceContainerLow: colors.insetPanel,
            surfaceContainer: colors.panel,
            surfaceContainerHigh: colors.raisedPanel,
            surfaceContainerHighest: colors.outline,
            outline: colors.outline,
            outlineVariant: colors.outline,
            error: colors.danger,
            onError: colors.onDanger,
            errorContainer: colors.dangerContainer,
            onErrorContainer: colors.danger,
          ),
    scaffoldBackgroundColor: colors.canvas,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.standard,
    menuTheme: MenuThemeData(style: secretPodMenuStyle(colors)),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.insetPanel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outline),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.blue,
        foregroundColor: colors.onBlue,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        side: BorderSide(color: colors.outline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.raisedPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
