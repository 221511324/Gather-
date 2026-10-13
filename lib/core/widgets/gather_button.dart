import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// The primary pill button.
///
/// Handles its own busy state so callers can hand it an async action without
/// each screen re-implementing a loading flag.
class GatherButton extends StatefulWidget {
  const GatherButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.foreground,
    this.expand = true,
    this.compact = false,
    this.busy = false,
  });

  final String label;

  /// May return a Future — the button shows a spinner until it settles.
  final FutureOr<void> Function()? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final bool expand;
  final bool compact;

  /// Forces the busy state from outside, for callers that own the flag.
  final bool busy;

  @override
  State<GatherButton> createState() => _GatherButtonState();
}

class _GatherButtonState extends State<GatherButton> {
  bool _running = false;

  bool get _busy => _running || widget.busy;

  Future<void> _handle() async {
    final action = widget.onPressed;
    if (action == null || _busy) return;
    final result = action();
    if (result is Future<void>) {
      setState(() => _running = true);
      try {
        await result;
      } finally {
        if (mounted) setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_busy;
    final background = widget.color ?? AppColors.primary;
    final foreground = widget.foreground ?? Colors.white;

    final button = FilledButton(
      onPressed: enabled ? _handle : null,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: _busy ? background.withValues(alpha: 0.7) : AppColors.line,
        disabledForegroundColor: _busy ? foreground : AppColors.inkFaint,
        minimumSize: widget.expand
            ? Size.fromHeight(widget.compact ? 46 : 56)
            : Size(0, widget.compact ? 46 : 56),
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? Insets.lg : Insets.xxl),
        textStyle: widget.compact ? AppType.label.copyWith(fontSize: 15) : AppType.button,
      ),
      child: _busy
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: widget.compact ? 17 : 20),
                  const SizedBox(width: Insets.sm),
                ],
                Flexible(
                  child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
    );

    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The secondary action — same geometry, outlined.
class GatherOutlineButton extends StatelessWidget {
  const GatherOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: tint,
        side: BorderSide(color: onPressed == null ? AppColors.line : tint, width: 1.6),
        minimumSize:
            expand ? Size.fromHeight(compact ? 46 : 56) : Size(0, compact ? 46 : 56),
        padding: EdgeInsets.symmetric(horizontal: compact ? Insets.lg : Insets.xxl),
        textStyle: compact ? AppType.label.copyWith(fontSize: 15) : AppType.button,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 17 : 20),
            const SizedBox(width: Insets.sm),
          ],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A soft-filled circular icon button used on cards and list rows.
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.background,
    this.size = 40,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? background;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final widget = Material(
      color: background ?? AppColors.primarySoft,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.46, color: color ?? AppColors.primary),
        ),
      ),
    );
    return tooltip == null ? widget : Tooltip(message: tooltip!, child: widget);
  }
}
