import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.accentSoft,
      onSecondaryContainer: AppColors.accentDeep,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppType.family,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppType.headline,
        iconTheme: const IconThemeData(color: AppColors.ink),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      // Defaults for incidental buttons — dialog actions, inline confirms.
      // The full-width 56px page button is GatherButton's own shape, set
      // there rather than here so it cannot leak into a dialog.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size(72, 44),
          textStyle: AppType.label.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: Radii.brPill),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(72, 44),
          textStyle: AppType.label.copyWith(fontSize: 15),
          side: const BorderSide(color: AppColors.primary, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: Radii.brPill),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppType.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.primarySoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.lg),
        hintStyle: AppType.body.copyWith(color: AppColors.inkFaint, fontSize: 15),
        labelStyle: AppType.label.copyWith(color: AppColors.inkMuted),
        floatingLabelStyle: AppType.label.copyWith(color: AppColors.primary),
        errorStyle: AppType.caption.copyWith(color: AppColors.danger),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.6),
        disabledBorder: _inputBorder(Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Radii.brLg),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        selectedColor: AppColors.primary,
        labelStyle: AppType.label,
        secondaryLabelStyle: AppType.label.copyWith(color: Colors.white),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: Radii.brPill),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.sheetTop),
        showDragHandle: true,
        dragHandleColor: AppColors.line,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.brXl),
        titleTextStyle: AppType.title.copyWith(fontSize: 20),
        contentTextStyle: AppType.body.copyWith(fontSize: 15, color: AppColors.inkMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppType.body.copyWith(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.brMd),
        insetPadding: const EdgeInsets.all(Insets.lg),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: AppColors.primarySoft,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.inkFaint,
        labelStyle: AppType.label,
        unselectedLabelStyle: AppType.body.copyWith(fontSize: 14),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.inkMuted,
        titleTextStyle: AppType.bodyStrong,
        subtitleTextStyle: AppType.caption,
        shape: RoundedRectangleBorder(borderRadius: Radii.brMd),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.2}) => OutlineInputBorder(
        borderRadius: Radii.brMd,
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme get _textTheme => TextTheme(
        displayLarge: AppType.display,
        displayMedium: AppType.screenTitle,
        headlineLarge: AppType.title,
        headlineMedium: AppType.subtitle,
        headlineSmall: AppType.headline,
        titleLarge: AppType.headline,
        titleMedium: AppType.bodyStrong,
        titleSmall: AppType.label,
        bodyLarge: AppType.bodyLarge,
        bodyMedium: AppType.body,
        bodySmall: AppType.caption,
        labelLarge: AppType.label,
        labelMedium: AppType.caption,
        labelSmall: AppType.overline,
      );
}
