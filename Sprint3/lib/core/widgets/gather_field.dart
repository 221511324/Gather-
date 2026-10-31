import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../l10n/tr.dart';

/// A labelled, soft-filled text field — the input style the design uses
/// everywhere: a bold label above, a tinted rounded field below, no border
/// until focus.
class GatherField extends StatefulWidget {
  const GatherField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.validator,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.initialValue,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.textDirection,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Adds the show/hide toggle automatically.
  final bool obscure;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final List<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? initialValue;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  /// For values that always read left to right, such as a phone number, so
  /// Arabic does not move the '+' to the end. The text still lines up with
  /// the layout's start edge.
  final TextDirection? textDirection;

  @override
  State<GatherField> createState() => _GatherFieldState();
}

class _GatherFieldState extends State<GatherField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr(widget.label),
        style: AppType.label.copyWith(fontSize: 15),
      ),
      const SizedBox(height: Insets.sm),
      TextFormField(
        controller: widget.controller,
        initialValue: widget.controller == null ? widget.initialValue : null,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: _hidden,
        // Validators return English; the message is shown in the app's language.
        validator: widget.validator == null
            ? null
            : (v) {
                final error = widget.validator!(v);
                return error == null ? null : context.tr(error);
              },
        maxLines: widget.obscure ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        autofillHints: widget.autofillHints,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        autofocus: widget.autofocus,
        textCapitalization: widget.textCapitalization,
        textDirection: widget.textDirection,
        textAlign: widget.textDirection == null
            ? TextAlign.start
            : (Directionality.of(context) == TextDirection.rtl
                  ? TextAlign.right
                  : TextAlign.left),
        style: AppType.bodyLarge.copyWith(fontSize: 16),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: widget.hint == null ? null : context.tr(widget.hint!),
          helperText: widget.helper == null ? null : context.tr(widget.helper!),
          helperStyle: AppType.caption,
          counterText: '',
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(widget.prefixIcon, size: 20, color: AppColors.inkMuted),
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                  tooltip: context.tr(
                    _hidden ? 'Show password' : 'Hide password',
                  ),
                )
              : widget.suffix,
        ),
      ),
    ],
  );
}

/// The rounded search pill from the design, with the accent action button on
/// its right edge.
class GatherSearchField extends StatelessWidget {
  const GatherSearchField({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.trailingIcon = Icons.tune_rounded,
    this.onTrailingTap,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  /// True when the field is a button that opens the search screen.
  final bool readOnly;
  final bool autofocus;
  final IconData trailingIcon;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    decoration: BoxDecoration(color: Colors.white, borderRadius: Radii.brPill),
    padding: const EdgeInsetsDirectional.only(start: Insets.lg, end: Insets.xs),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, size: 21, color: AppColors.inkFaint),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTap: onTap,
            readOnly: readOnly,
            autofocus: autofocus,
            textInputAction: TextInputAction.search,
            style: AppType.bodyLarge.copyWith(fontSize: 15),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: context.tr(hint),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintStyle: AppType.body.copyWith(
                color: AppColors.inkFaint,
                fontSize: 15,
              ),
            ),
          ),
        ),
        if (onTrailingTap != null)
          Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTrailingTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(trailingIcon, size: 19, color: AppColors.ink),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The boxed digit entry used for the 4-digit session code.
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.onCompleted,
    this.length = 4,
    this.onChanged,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      _focus.unfocus();
      widget.onCompleted(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text;

    return SizedBox(
      height: 66,
      child: Stack(
        children: [
          // The real field is invisible and sized to nothing; the boxes below
          // are the visible UI and forward taps to it.
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onChanged,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _focus.requestFocus(),
              behavior: HitTestBehavior.opaque,
              child: Row(
                // A code reads left to right in Arabic too.
                textDirection: TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.length, (i) {
                  final filled = i < value.length;
                  final isNext = i == value.length && _focus.hasFocus;
                  // Flexible so four boxes still fit a narrow phone; they
                  // keep their 58pt width wherever there is room.
                  return Flexible(
                    child: Container(
                      width: 58,
                      height: 66,
                      margin: const EdgeInsets.symmetric(horizontal: Insets.sm),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: filled
                            ? AppColors.primarySoft
                            : AppColors.surface,
                        borderRadius: Radii.brMd,
                        border: Border.all(
                          color: isNext
                              ? AppColors.primary
                              : (filled
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : AppColors.line),
                          width: isNext ? 2 : 1.4,
                        ),
                      ),
                      child: Text(
                        filled ? value[i] : '',
                        style: AppType.title.copyWith(
                          fontSize: 26,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
