import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/member_avatar.dart';

/// One line in any cart.
///
/// [showOwner] turns on the avatar and name, which is what makes a shared
/// cart readable — every item stays attributable to the member who added it
/// (FR12).
class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.line,
    this.onQuantityChanged,
    this.onRemove,
    this.onTap,
    this.showOwner = false,
    this.readOnly = false,
  });

  final CartLine line;
  final ValueChanged<int>? onQuantityChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final bool showOwner;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImage(url: line.imageUrl, width: 72, height: 72, radius: Radii.md),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.isolate(line.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyStrong.copyWith(fontSize: 15),
                        ),
                      ),
                      Text(
                        Money.format(line.lineTotal),
                        style: AppType.money.copyWith(fontSize: 14.5),
                      ),
                    ],
                  ),
                  if (line.optionSummary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.isolate(line.optionSummary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(fontSize: 12),
                    ),
                  ],
                  if (line.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 14, color: AppColors.accentDeep),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            context.isolate(line.note),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption.copyWith(
                              fontSize: 12,
                              color: AppColors.accentDeep,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      if (showOwner) ...[
                        MemberAvatar(
                          uid: line.ownerId,
                          initials: _initials(line.ownerName),
                          size: 22,
                        ),
                        const SizedBox(width: Insets.xs + 2),
                        Flexible(
                          child: Text(
                            context.isolate(line.ownerName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption.copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (readOnly)
                        Text('×${line.quantity}', style: AppType.bodyStrong)
                      else if (onQuantityChanged != null)
                        QuantityStepper(
                          quantity: line.quantity,
                          compact: true,
                          allowRemove: onRemove != null,
                          onChanged: (q) =>
                              q <= 0 && onRemove != null ? onRemove!() : onQuantityChanged!(q),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

/// The subtotal / fees / total block shared by the cart, checkout and order
/// screens so money is always presented the same way.
class TotalsPanel extends StatelessWidget {
  const TotalsPanel({
    super.key,
    required this.totals,
    this.voucherCode,
    this.perPersonLabel,
    this.dense = false,
  });

  final CartTotals totals;
  final String? voucherCode;

  /// Optional "each pays" line for group orders.
  final String? perPersonLabel;
  final bool dense;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _Row(label: 'Subtotal', value: Money.format(totals.subtotal), dense: dense),
          _Row(
            label: 'Delivery',
            value: totals.deliveryFee == 0 ? context.tr('Free') : Money.format(totals.deliveryFee),
            dense: dense,
          ),
          _Row(label: 'Service fee', value: Money.format(totals.serviceFee), dense: dense),
          if (totals.discount > 0)
            _Row(
              label: voucherCode == null
                  ? 'Discount'
                  : context.tr('Discount ({code})', {'code': voucherCode}),
              value: '−${Money.format(totals.discount)}',
              color: AppColors.success,
              dense: dense,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.md),
            child: Divider(height: 1),
          ),
          _Row(
            label: 'Total',
            value: Money.format(totals.total),
            emphasis: true,
            dense: dense,
          ),
          if (perPersonLabel != null) ...[
            const SizedBox(height: Insets.xs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(context.tr(perPersonLabel!), style: AppType.caption),
            ),
          ],
        ],
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.color,
    this.emphasis = false,
    this.dense = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool emphasis;
  final bool dense;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 3 : 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              // Callers pass English; an already-translated label passes through.
              context.tr(label),
              style: emphasis
                  ? AppType.headline.copyWith(fontSize: 17)
                  : AppType.body.copyWith(color: color ?? AppColors.inkMuted, fontSize: 14),
            ),
            Text(
              value,
              style: emphasis
                  ? AppType.money.copyWith(fontSize: 19, color: AppColors.primary)
                  : AppType.money.copyWith(
                      fontSize: 14,
                      color: color ?? AppColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
            ),
          ],
        ),
      );
}
