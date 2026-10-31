import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';

const _starters = [
  'What is the best dessert?',
  'Something vegan under 30',
  'Which is the fastest delivery?',
  'How do I split the bill?',
];

/// US14 — ask Gather what to eat.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final question = (preset ?? _input.text).trim();
    final uid = ref.read(currentUidProvider);
    if (question.isEmpty || uid == null || _thinking) return;

    final languageCode = Localizations.localeOf(context).languageCode;
    final history =
        ref.read(assistantConversationProvider).valueOrNull ?? const [];
    setState(() => _thinking = true);
    _input.clear();
    _scrollToEnd();

    final result = await ref.read(assistantServiceProvider).ask(
          uid: uid,
          question: question,
          context: ref.read(assistantContextProvider),
          languageCode: languageCode,
          history: history,
        );

    if (!mounted) return;
    setState(() => _thinking = false);
    if (result case Err(:final message)) AppSnack.error(context, message);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(assistantConversationProvider);
    ref.listen(assistantConversationProvider, (_, _) => _scrollToEnd());

    return BrandScaffold(
      title: 'Food assistant',
      showBack: true,
      actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: context.tr('Clear conversation'),
            onPressed: () async {
              final uid = ref.read(currentUidProvider);
              if (uid == null) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.tr('Clear this conversation?')),
                  content: Text(context.tr('The messages are removed from your account.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.tr('Cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.tr('Clear'),
                            style: const TextStyle(color: AppColors.danger))),
                  ],
                ),
              );
              if (confirmed != true) return;
              await ref.read(assistantServiceProvider).clear(uid);
            },
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: conversation.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: '$e'),
              data: (messages) {
                // A hosted model can take a few seconds, so the first question
                // also shows the typing bubble rather than an unchanged welcome.
                if (messages.isEmpty && !_thinking) return _Welcome(onPick: _send);
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(Insets.gutter),
                  itemCount: messages.length + (_thinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= messages.length) return const _Thinking();
                    return _Bubble(message: messages[i]);
                  },
                );
              },
            ),
          ),
          _Composer(controller: _input, busy: _thinking, onSend: _send),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(Insets.gutter),
        children: [
          const SizedBox(height: Insets.xxl),
          const Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.primary),
          const SizedBox(height: Insets.lg),
          Text(context.tr('What are you in the mood for?'),
              style: AppType.headline, textAlign: TextAlign.center),
          const SizedBox(height: Insets.sm),
          Text(
            context.tr('I answer from the restaurants and menus on Gather, so everything '
                'I suggest is something you can actually order.'),
            style: AppType.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.xxl),
          for (final s in _starters)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: OutlinedButton(
                // The English goes to the assistant, which matches on it.
                onPressed: () => onPick(s),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.line, width: 1.4),
                  foregroundColor: AppColors.ink,
                ),
                child: Text(context.tr(s)),
              ),
            ),
        ],
      );
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final items = ref.watch(allMenuItemsProvider).valueOrNull ?? const <MenuItem>[];
    final referenced = items.where((i) => message.itemIds.contains(i.id)).toList();

    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.only(bottom: Insets.md),
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.md, vertical: Insets.sm + 2),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(Radii.md),
            topEnd: const Radius.circular(Radii.md),
            bottomEnd: Radius.circular(isUser ? 4 : Radii.md),
            bottomStart: Radius.circular(isUser ? Radii.md : 4),
          ),
          border: isUser ? null : Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              // The local brain's replies are stored in English and translated
              // here; a model's reply is already in the person's language, so
              // Arabic text is shown as written. The person's own words are
              // shown as they typed them.
              isUser || _arabicScript.hasMatch(message.text)
                  ? context.isolate(message.text)
                  : context.tr(message.text),
              style:
                  AppType.body.copyWith(color: isUser ? Colors.white : AppColors.ink),
            ),
            if (!isUser && message.action != AssistantAction.none) ...[
              const SizedBox(height: Insets.xs),
              Text(context.tr(message.action.label),
                  style: AppType.caption.copyWith(color: AppColors.inkFaint)),
            ],
            if (referenced.isNotEmpty) ...[
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: [
                  for (final item in referenced)
                    ActionChip(
                      label: Text(context.isolate(item.name)),
                      backgroundColor: AppColors.primaryTint,
                      side: BorderSide.none,
                      labelStyle:
                          AppType.caption.copyWith(color: AppColors.primary),
                      onPressed: () =>
                          context.push(Routes.restaurant(item.restaurantId)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final _arabicScript = RegExp(r'[\u0600-\u06FF]');

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: Insets.md),
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: Insets.sm),
              Text(context.tr('Typing…'),
                  style: AppType.caption.copyWith(color: AppColors.inkFaint)),
            ],
          ),
        ),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          Insets.gutter,
          Insets.sm,
          Insets.gutter,
          Insets.md + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GatherField(
                label: 'Ask',
                controller: controller,
                hint: 'Ask about food, or about using Gather',
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: Insets.sm),
            IconButton.filled(
              onPressed: busy ? null : () => onSend(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(52, 52),
              ),
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ],
        ),
      );
}
