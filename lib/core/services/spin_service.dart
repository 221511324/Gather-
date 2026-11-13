import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/spin.dart';
import '../models/voucher.dart';
import '../utils/parse.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// Spin & Win (FR25) — one free spin every 24 hours, and every spin wins.
///
/// The prize is drawn here, before the wheel moves; the screen only animates
/// to it. The 24-hour check, the voucher and the new `lastSpinAt` are one
/// transaction on `users/{uid}`, so a double tap or a second phone cannot
/// spin twice: the second transaction re-reads the profile, sees the first
/// spin and gives up.
class SpinService {
  SpinService(this.refs, {Random? random}) : _random = random ?? Random.secure();

  final FirestoreRefs refs;
  final Random _random;
  static const _uuid = Uuid();
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// The wheel as it stands: admin rewards flagged for it, or the built-in table.
  Stream<List<SpinPrize>> watchWheel() => refs.vouchers.snapshots().map((s) =>
      SpinRules.wheelFor(s.docs
          .where((d) => d.id != '_schema')
          .map((d) => Voucher.fromMap(d.id, d.data()))
          .toList()));

  /// Spins [prizes] — the wheel the person is looking at — for [uid].
  Future<Result<SpinOutcome>> spin({
    required String uid,
    required List<SpinPrize> prizes,
  }) async {
    if (prizes.isEmpty) return const Err('The wheel has no prizes yet');
    final index = SpinRules.pickIndex(prizes, _random);
    final prize = prizes[index];
    final voucherRef = refs.userVouchers(uid).doc(_uuid.v4());

    try {
      final won = await refs.db.runTransaction<UserVoucher?>((tx) async {
        final profile = await tx.get(refs.user(uid));
        final now = DateTime.now();
        final last = Parse.dateOrNull(profile.data()?['lastSpinAt']);
        if (!SpinRules.canSpin(last, now)) return null;

        final voucher = prize.toUserVoucher(id: voucherRef.id, code: _code(), now: now);
        tx.set(voucherRef, {
          ...voucher.toMap(),
          'grantedAt': FieldValue.serverTimestamp(),
          'source': 'spin',
        });
        // The device clock, not a server timestamp: a pending server
        // timestamp reads back as null until the write lands, which would
        // flash "your free spin is ready" for a moment after spinning.
        tx.update(refs.user(uid), {'lastSpinAt': Timestamp.fromDate(now)});
        return voucher;
      });
      if (won == null) return const Err('You have already used your spin. Come back later.');
      return Ok(SpinOutcome(index: index, prize: prize, voucher: won));
    } on FirebaseException catch (e) {
      return Err(e.code == 'permission-denied'
          ? 'You do not have permission to do that'
          : e.message ?? 'Could not spin the wheel');
    }
  }

  /// Opens the next spin right away. For integration tests and demos only —
  /// the person's own profile rules allow it, but no screen offers it.
  @visibleForTesting
  Future<void> resetSpin(String uid) =>
      refs.user(uid).update({'lastSpinAt': FieldValue.delete()});

  String _code() =>
      'SPIN-${List.generate(6, (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)]).join()}';
}
