import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';

class _Faq {
  const _Faq(this.question, this.answer);

  final String question;
  final String answer;
}

/// FAQs covering the parts of Gather people ask about most. The English
/// below is also the translation key, so the Arabic lives in `ar/account.dart`.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  int? _open;

  static const _sections = {
    'Group ordering': [
      _Faq(
        'How do I start a group order?',
        'Open the Group tab and tap "New session". Give it a name, then share the '
            '4-digit code, send the invite link, or add people directly by their '
            'Gather username or phone number.',
      ),
      _Faq(
        'How does someone join my session?',
        'They can enter your 4-digit code on the Join screen, tap your invite link, '
            'or accept the invitation that appears in their notifications when you '
            'add them by username or phone number.',
      ),
      _Faq(
        'Can everyone change the order?',
        'Everyone adds their own items to the shared cart, and everyone can see the '
            'whole order. Only the person who added an item can change or remove it.',
      ),
      _Faq(
        'What happens if we cannot agree on a restaurant?',
        'Each member suggests a place. Those suggestions go on a wheel, and the host '
            'spins it. Every suggestion has an equal chance, and the whole group sees '
            'the same result.',
      ),
      _Faq(
        'Can I reuse the same group next time?',
        'Yes. Open the session menu and tap "Save this group". It appears under '
            'Saved groups, and starting from it invites the same people again.',
      ),
    ],
    'Payment': [
      _Faq(
        'How is the bill split?',
        'The host picks one of three options: everyone pays for their own items, the '
            'total is split equally, or the host pays for everyone.',
      ),
      _Faq(
        'Who pays the delivery fee?',
        'When everyone pays for their own items, the delivery and service fees are '
            'divided evenly across the group, since they are charged once for the '
            'whole order.',
      ),
      _Faq(
        'When is the order actually placed?',
        'The host can place it once nobody is still pending on the payment screen. '
            'Until then, the order is held.',
      ),
      _Faq(
        'Is my card information safe?',
        'Gather stores only the card brand and the last four digits. The full number '
            'is validated on your device and is never written to our database.',
      ),
    ],
    'Orders and delivery': [
      _Faq(
        'How do I track my order?',
        'Open the Orders tab and choose the active order. The timeline shows each '
            'step from confirmation to delivery, with times.',
      ),
      _Faq(
        'Can I cancel an order?',
        'Yes, while it is still confirmed or being prepared. Once it has left the '
            'restaurant it can no longer be cancelled from the app.',
      ),
      _Faq(
        'Can I reorder something?',
        'Open a past order and tap "Order again". For a group order, only your own '
            'items are added back to your cart.',
      ),
    ],
    'Rewards': [
      _Faq(
        'How does Spin & Win work?',
        'You get one free spin each day. Every spin wins something — a percentage '
            'off, an amount off, or free delivery. The bigger prizes are rarer.',
      ),
      _Faq(
        'How do I use a voucher?',
        'At checkout, tap the reward row and pick one from your wallet, or type a '
            'code. The discount comes off your total immediately.',
      ),
      _Faq(
        'Do rewards expire?',
        'Yes — rewards expire 14 days after you win them. Your wallet shows the '
            'status of every one.',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    // Flattened up front, with each entry carrying its own identity and
    // whether it opens a new section — no build-order bookkeeping.
    final entries = <({String? heading, _Faq faq, int index})>[];
    for (final section in _sections.entries) {
      for (var i = 0; i < section.value.length; i++) {
        entries.add((
          heading: i == 0 ? section.key : null,
          faq: section.value[i],
          index: entries.length,
        ));
      }
    }

    return BrandScaffold(
      title: 'Help & FAQs',
      showBack: true,
      padBody: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxxl),
        children: [
          for (final entry in entries) ...[
            if (entry.heading != null)
              Padding(
                padding: EdgeInsets.only(
                  bottom: Insets.md,
                  top: entry.index == 0 ? Insets.sm : Insets.lg,
                ),
                child: Text(context.tr(entry.heading!), style: AppType.title.copyWith(fontSize: 19)),
              ),
            _FaqCard(
              faq: entry.faq,
              expanded: _open == entry.index,
              onTap: () => setState(() => _open = _open == entry.index ? null : entry.index),
            ),
            const SizedBox(height: Insets.md),
          ],
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.faq, required this.expanded, required this.onTap});

  final _Faq faq;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(faq.question),
                    style: AppType.bodyStrong.copyWith(fontSize: 14.5),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: Motion.fast,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: Insets.md),
                child: Text(
                  context.tr(faq.answer),
                  style: AppType.body.copyWith(
                    fontSize: 13.5,
                    height: 1.55,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              crossFadeState:
                  expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: Motion.fast,
            ),
          ],
        ),
      );
}
