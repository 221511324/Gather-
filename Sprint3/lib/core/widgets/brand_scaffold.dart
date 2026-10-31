import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../l10n/tr.dart';

/// The page shell the whole app is built on.
///
/// A brand-coloured band carries the title and any hero content, and the page
/// body sits on a rounded sheet that overlaps it. It is the single structural
/// idea the design leans on, so it lives in one widget rather than being
/// rebuilt per screen.
class BrandScaffold extends StatelessWidget {
  const BrandScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.bandContent,
    this.actions,
    this.leading,
    this.showBack = false,
    this.onBack,
    this.floatingActionButton,
    this.bottomBar,
    this.scrollable = false,
    this.padBody = true,
    this.bandHeight,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Replaces the title text entirely (used by the home screen's greeting).
  final Widget? titleWidget;

  /// Extra content pinned inside the band, below the title — a search field,
  /// a session code, a summary row.
  final Widget? bandContent;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? floatingActionButton;
  final Widget? bottomBar;

  /// Wraps [child] in a scroll view. Leave false when the body manages its own
  /// scrolling (a ListView, a TabBarView).
  final bool scrollable;
  final bool padBody;
  final double? bandHeight;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.band,
        floatingActionButton: floatingActionButton,
        body: Column(
          children: [
            _Band(
              topPadding: media.padding.top,
              title: title,
              subtitle: subtitle,
              titleWidget: titleWidget,
              content: bandContent,
              actions: actions,
              leading: leading,
              showBack: showBack,
              onBack: onBack,
              height: bandHeight,
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: Radii.sheetTop,
                ),
                clipBehavior: Clip.antiAlias,
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: scrollable
                      ? SingleChildScrollView(
                          padding: _bodyPadding(media),
                          child: child,
                        )
                      : Padding(padding: _bodyPadding(media), child: child),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }

  EdgeInsets _bodyPadding(MediaQueryData media) => padBody
      ? EdgeInsets.fromLTRB(
          Insets.gutter,
          Insets.xxl,
          Insets.gutter,
          Insets.xxl + (bottomBar == null ? media.padding.bottom : 0),
        )
      : EdgeInsets.zero;
}

class _Band extends StatelessWidget {
  const _Band({
    required this.topPadding,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.content,
    this.actions,
    this.leading,
    this.showBack = false,
    this.onBack,
    this.height,
  });

  final double topPadding;
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final hasHeaderRow = showBack || leading != null || title != null || (actions?.isNotEmpty ?? false);

    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(gradient: AppColors.bandGradient),
      padding: EdgeInsets.fromLTRB(Insets.gutter, topPadding + Insets.sm, Insets.gutter, Insets.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeaderRow)
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  if (showBack)
                    _BandIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    )
                  else
                    ?leading,
                  if (showBack || leading != null) const SizedBox(width: Insets.md),
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Text(
                            context.tr(title!),
                            style: AppType.headline.copyWith(color: Colors.white, fontSize: 19),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                          ),
                  ),
                  if (actions != null) ...[
                    const SizedBox(width: Insets.sm),
                    ...actions!,
                  ],
                ],
              ),
            ),
          if (titleWidget != null) ...[
            if (hasHeaderRow) const SizedBox(height: Insets.md),
            titleWidget!,
          ],
          if (subtitle != null) ...[
            const SizedBox(height: Insets.xs),
            Text(
              context.tr(subtitle!),
              style: AppType.body.copyWith(color: Colors.white.withValues(alpha: 0.92), fontSize: 14),
            ),
          ],
          if (content != null) ...[
            const SizedBox(height: Insets.lg),
            content!,
          ],
        ],
      ),
    );
  }
}

/// A circular translucent button sized for the brand band.
class _BandIconButton extends StatelessWidget {
  const _BandIconButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => BandIconButton(icon: icon, onTap: onTap, tooltip: tooltip);
}

class BandIconButton extends StatelessWidget {
  const BandIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// Renders a count bubble — used for the cart and notification buttons.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 19, color: Colors.white)),
      ),
    );

    final wrapped = badgeCount <= 0
        ? button
        : Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              PositionedDirectional(
                end: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: Radii.brPill,
                    border: Border.all(color: AppColors.bandDeep, width: 1.5),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: AppType.overline.copyWith(color: AppColors.ink, fontSize: 10, height: 1.2),
                  ),
                ),
              ),
            ],
          );

    return tooltip == null ? wrapped : Tooltip(message: context.tr(tooltip!), child: wrapped);
  }
}

/// A plain white page for flows that should not carry the brand band —
/// full-screen dialogs, the item detail sheet, the spin screens.
class PlainScaffold extends StatelessWidget {
  const PlainScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showBack = true,
    this.backgroundColor,
    this.bottomBar,
    this.padBody = true,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBack;
  final Color? backgroundColor;
  final Widget? bottomBar;
  final bool padBody;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: backgroundColor ?? AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: title == null ? null : Text(context.tr(title!)),
            leading: showBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: context.tr('Back'),
                  )
                : null,
            actions: actions,
          ),
          body: SafeArea(
            top: false,
            child: padBody
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                    child: child,
                  )
                : child,
          ),
          bottomNavigationBar: bottomBar,
        ),
      );
}
