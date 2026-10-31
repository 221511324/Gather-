import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';

/// Saved delivery addresses (FR2).
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const BrandScaffold(title: 'Addresses', showBack: true, child: LoadingView());
    }

    Future<void> save(List<Address> next) async {
      final result = await ref.read(authServiceProvider).saveAddresses(user.uid, next);
      if (!context.mounted) return;
      if (result case Err(:final message)) AppSnack.error(context, message);
    }

    return BrandScaffold(
      title: 'Delivery addresses',
      showBack: true,
      padBody: false,
      bottomBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
        child: GatherButton(
          label: 'Add an address',
          icon: Icons.add_location_alt_outlined,
          onPressed: () async {
            final created = await AddressSheet.show(context);
            if (created == null) return;
            await save([
              ...user.addresses.map(
                (a) => created.isDefault ? a.copyWith(isDefault: false) : a,
              ),
              created,
            ]);
          },
        ),
      ),
      child: user.addresses.isEmpty
          ? const EmptyView(
              icon: Icons.location_off_outlined,
              title: 'No addresses yet',
              message: 'Add one so we know where to deliver your orders.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
              itemCount: user.addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
              itemBuilder: (context, i) {
                final address = user.addresses[i];
                return GatherCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconFor(address.label),
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(addressLabel(context, address.label), style: AppType.bodyStrong),
                                if (address.isDefault) ...[
                                  const SizedBox(width: Insets.sm),
                                  const StatusPill(
                                    label: 'Default',
                                    color: AppColors.primary,
                                    compact: true,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(context.isolate(address.oneLine), style: AppType.caption),
                            if (address.notes.isNotEmpty)
                              Text(
                                context.isolate(address.notes),
                                style: AppType.caption.copyWith(fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkFaint),
                        tooltip: context.tr('Address options'),
                        onSelected: (value) async {
                          switch (value) {
                            case 'default':
                              await save([
                                for (final a in user.addresses)
                                  a.copyWith(isDefault: a.id == address.id),
                              ]);
                            case 'edit':
                              final edited = await AddressSheet.show(context, existing: address);
                              if (edited == null) return;
                              await save([
                                for (final a in user.addresses)
                                  if (a.id == address.id)
                                    edited
                                  else
                                    (edited.isDefault ? a.copyWith(isDefault: false) : a),
                              ]);
                            case 'delete':
                              await save(
                                user.addresses.where((a) => a.id != address.id).toList(),
                              );
                          }
                        },
                        itemBuilder: (context) => [
                          if (!address.isDefault)
                            PopupMenuItem(value: 'default', child: Text(context.tr('Set as default'))),
                          PopupMenuItem(value: 'edit', child: Text(context.tr('Edit'))),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(context.tr('Delete'),
                                style: const TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  static IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('home')) return Icons.home_rounded;
    if (l.contains('work') || l.contains('office')) return Icons.work_rounded;
    if (l.contains('uni') || l.contains('school') || l.contains('campus')) return Icons.school_rounded;
    return Icons.location_on_rounded;
  }
}

/// An address's label for display. Preset labels ("Home", "Work") are stored
/// in English and translated; a custom one has no entry and shows as typed,
/// isolated so its own direction holds.
String addressLabel(BuildContext context, String label) {
  final said = context.tr('$label|address');
  return said == label ? context.isolate(label) : said;
}

/// Add or edit one address.
class AddressSheet extends StatefulWidget {
  const AddressSheet({super.key, this.existing});

  final Address? existing;

  static Future<Address?> show(BuildContext context, {Address? existing}) =>
      showModalBottomSheet<Address>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => AddressSheet(existing: existing),
      );

  @override
  State<AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<AddressSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  late final _line = TextEditingController(text: widget.existing?.line ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late bool _isDefault = widget.existing?.isDefault ?? false;

  static const _presets = ['Home', 'Work', 'University', 'Other'];

  @override
  void dispose() {
    _label.dispose();
    _line.dispose();
    _city.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      Address(
        id: widget.existing?.id ?? const Uuid().v4(),
        label: _label.text.trim(),
        line: _line.text.trim(),
        city: _city.text.trim(),
        notes: _notes.text.trim(),
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            Insets.gutter,
            Insets.sm,
            Insets.gutter,
            Insets.xl + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(widget.existing == null ? 'Add an address' : 'Edit address'),
                  style: AppType.headline,
                ),
                const SizedBox(height: Insets.xl),
                Wrap(
                  spacing: Insets.sm,
                  children: [
                    for (final preset in _presets)
                      ChoiceChip(
                        label: Text(context.tr('$preset|address')),
                        selected: _label.text.trim().toLowerCase() == preset.toLowerCase(),
                        onSelected: (_) => setState(() => _label.text = preset),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Label',
                  controller: _label,
                  hint: 'Home|address',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Give this address a label' : null,
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Street address',
                  controller: _line,
                  hint: 'Building, street, district',
                  maxLines: 2,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the address' : null,
                ),
                const SizedBox(height: Insets.lg),
                GatherField(label: 'City', controller: _city, hint: 'Riyadh'),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Delivery notes (optional)',
                  controller: _notes,
                  hint: 'Gate code, floor, landmark',
                ),
                const SizedBox(height: Insets.lg),
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: Text(context.tr('Use as my default address'), style: AppType.bodyLarge.copyWith(fontSize: 15)),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                ),
                const SizedBox(height: Insets.lg),
                GatherButton(
                  label: widget.existing == null ? 'Add address' : 'Save changes',
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      );
}
