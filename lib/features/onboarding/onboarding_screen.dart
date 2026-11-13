import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/app_prefs.dart';
import '../../core/widgets/gather_button.dart';

class _Slide {
  const _Slide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// Three screens explaining what makes Gather different from ordering alone.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.group_add_rounded,
      title: 'Order together,\nnot one at a time',
      body: 'Start a session and invite everyone with a 4-digit code, a link, '
          'a username or a phone number. No more taking orders one by one.',
    ),
    _Slide(
      icon: Icons.casino_rounded,
      title: 'Settle the\n"where should we eat"',
      body: 'Everyone suggests a place. If the group still cannot agree, spin '
          'the wheel and let it decide — fairly, and in front of everyone.',
    ),
    _Slide(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Split the bill\nhowever you like',
      body: 'Everyone pays for their own items, split the total equally, or '
          'let the host cover it. You can see who has paid before ordering.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Marks onboarding seen so it does not reappear, then hands over to the
  /// chosen destination.
  Future<void> _finish(String destination) async {
    await ref.read(appPrefsProvider).markOnboardingSeen();
    ref.read(onboardingSeenProvider.notifier).state = true;
    if (mounted) context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => _finish(Routes.login),
                child: Text(context.tr('Skip'), style: AppType.label.copyWith(color: AppColors.inkMuted)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.xxxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 118,
                          height: 118,
                          decoration: const BoxDecoration(
                            gradient: AppColors.bandGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 54, color: Colors.white),
                        ),
                        const SizedBox(height: Insets.xxxl),
                        Text(context.tr(slide.title), style: AppType.display.copyWith(fontSize: 30)),
                        const SizedBox(height: Insets.lg),
                        Text(
                          context.tr(slide.body),
                          style: AppType.bodyLarge.copyWith(color: AppColors.inkMuted, height: 1.55),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.xxl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: Motion.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: i == _page ? 26 : 8,
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.primary : AppColors.line,
                          borderRadius: Radii.brPill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.xxl),
                  GatherButton(
                    label: isLast ? 'Create my account' : 'Next',
                    onPressed: () {
                      if (isLast) {
                        _finish(Routes.register);
                      } else {
                        _controller.nextPage(duration: Motion.normal, curve: Motion.curve);
                      }
                    },
                  ),
                  const SizedBox(height: Insets.md),
                  TextButton(
                    onPressed: () => _finish(Routes.login),
                    child: Text.rich(
                      TextSpan(
                        text: context.tr('Already have an account? '),
                        style: AppType.body.copyWith(color: AppColors.inkMuted),
                        children: [
                          TextSpan(
                            text: context.tr('Log in'),
                            style: AppType.label.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
