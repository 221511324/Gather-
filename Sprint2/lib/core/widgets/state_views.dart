import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'gather_button.dart';

/// The empty state used across lists — a soft icon disc, a short headline and
/// an optional action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Insets.xxl,
            vertical: compact ? Insets.xl : Insets.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 64 : 84,
                height: compact ? 64 : 84,
                decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: Icon(icon, size: compact ? 28 : 36, color: AppColors.primary),
              ),
              SizedBox(height: compact ? Insets.md : Insets.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? AppType.headline : AppType.subtitle.copyWith(fontWeight: FontWeight.w600),
              ),
              if (message != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.inkMuted, fontSize: 14.5),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Insets.xl),
                GatherButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                  compact: compact,
                ),
              ],
            ],
          ),
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
            if (message != null) ...[
              const SizedBox(height: Insets.lg),
              Text(message!, style: AppType.body.copyWith(color: AppColors.inkMuted)),
            ],
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyView(
        icon: Icons.wifi_off_rounded,
        title: 'Something went wrong',
        message: message,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
}

/// Section heading with the optional "View all" affordance from the design.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: Insets.md),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppType.title.copyWith(fontSize: 21))),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel!, style: AppType.label.copyWith(color: AppColors.primary)),
                    const Icon(Icons.chevron_right_rounded, size: 19, color: AppColors.primary),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// A small status pill — order status, payment state, session stage.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? Insets.sm : Insets.md,
          vertical: compact ? 3 : 6,
        ),
        decoration: BoxDecoration(
          color: background ?? color.withValues(alpha: 0.12),
          borderRadius: Radii.brPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 12 : 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: (compact ? AppType.overline : AppType.label).copyWith(
                color: color,
                fontSize: compact ? 10.5 : 12.5,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );
}

/// Toast helper so every screen reports success and failure identically.
abstract final class AppSnack {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: isError ? AppColors.danger : AppColors.band,
                size: 20,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  message,
                  style: AppType.body.copyWith(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          action: action,
          duration: Duration(seconds: isError ? 4 : 3),
        ),
      );
  }

  static void error(BuildContext context, String message) =>
      show(context, message, isError: true);
}
