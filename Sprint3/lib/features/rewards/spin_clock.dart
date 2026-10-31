import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr.dart';
import '../../core/models/spin.dart';
import '../../core/providers/providers.dart';

/// Rebuilds every second with the time left until the next spin
/// ([Duration.zero] when a spin is open), so a countdown ticks live and the
/// Spin button wakes up the moment the 24 hours are over.
class SpinClock extends ConsumerStatefulWidget {
  const SpinClock({super.key, required this.builder});

  final Widget Function(BuildContext context, Duration remaining) builder;

  @override
  ConsumerState<SpinClock> createState() => _SpinClockState();
}

class _SpinClockState extends ConsumerState<SpinClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Only a running countdown needs a fresh frame.
      final last = ref.read(lastSpinAtProvider);
      if (mounted && last != null && last.add(SpinRules.cooldown + const Duration(seconds: 2)).isAfter(DateTime.now())) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastSpinAtProvider);
    return widget.builder(context, SpinRules.timeUntilNextSpin(last, DateTime.now()));
  }
}

/// "13h 20m", or "4m 05s" in the last hour.
String spinCountdownText(BuildContext context, Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0
      ? context.tr('{h}h {m}m', {'h': h, 'm': m})
      : context.tr('{m}m {s}s', {'m': m, 's': s});
}

/// 13:20:05 — for the big clock on the Spin & Win screen.
String spinClockText(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
}
