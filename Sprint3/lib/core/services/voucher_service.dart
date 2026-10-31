import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/voucher.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// US15 — rewards and vouchers.
///
/// Two collections. `vouchers` is the catalogue an administrator manages;
/// `users/{uid}/vouchers` is what one person holds. A held voucher copies its
/// terms from the catalogue at the moment it is granted, so editing a
/// campaign afterwards cannot change what somebody was already promised.
class VoucherService {
  VoucherService(this.refs);

  final FirestoreRefs refs;
  static const _uuid = Uuid();

  // ----------------------------------------------------------- catalogue ---

  Stream<List<Voucher>> watchCatalogue() => refs.vouchers
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.id != '_schema')
          .map((d) => Voucher.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.code.compareTo(b.code)));

  Future<List<Voucher>> fetchCatalogue() async {
    final snapshot = await refs.vouchers.get();
    return snapshot.docs
        .where((d) => d.id != '_schema')
        .map((d) => Voucher.fromMap(d.id, d.data()))
        .toList();
  }

  /// Creates or updates a reward. Codes are unique, case-insensitively.
  Future<Result<Voucher>> upsert(Voucher voucher) async {
    final code = voucher.code.trim().toUpperCase();
    if (code.length < 3) return const Err('A code needs at least three characters');
    if (voucher.title.trim().isEmpty) return const Err('Give the reward a name');
    if (voucher.discountType != DiscountType.freeDelivery &&
        voucher.discountValue <= 0) {
      return const Err('The discount must be more than zero');
    }
    if (voucher.discountType == DiscountType.percentage &&
        voucher.discountValue > 100) {
      return const Err('A percentage cannot be over 100');
    }

    try {
      final existing = await fetchCatalogue();
      if (existing.any((v) => v.id != voucher.id && v.code == code)) {
        return Err('$code is already in use');
      }

      final isNew = voucher.id.isEmpty;
      final id = isNew ? _uuid.v4() : voucher.id;
      final saved = voucher.copyWith(code: code, title: voucher.title.trim());
      await refs.voucher(id).set({
        ...saved.toMap(),
        // Never write redeemedCount from here: it is incremented when a
        // reward is redeemed, and resending a stale value would undo those.
        if (isNew) 'redeemedCount': 0,
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final back = await refs.voucher(id).get();
      return Ok(Voucher.fromMap(id, back.data() ?? {}));
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not save that reward'));
    }
  }

  Future<Result<void>> setActive(String id, bool active) async {
    try {
      await refs.voucher(id).update({'isActive': active});
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not change that reward'));
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await refs.voucher(id).delete();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not remove that reward'));
    }
  }

  // --------------------------------------------------------- what I hold ---

  Stream<List<UserVoucher>> watchMine(String uid) => refs
      .userVouchers(uid)
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.id != '_schema')
          .map((d) => UserVoucher.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) {
          // Usable first, then by what expires soonest.
          final usable = (b.isUsable ? 1 : 0).compareTo(a.isUsable ? 1 : 0);
          if (usable != 0) return usable;
          return (a.expiresAt ?? DateTime(2100))
              .compareTo(b.expiresAt ?? DateTime(2100));
        }));

  Future<List<UserVoucher>> fetchMine(String uid) async {
    final snapshot = await refs.userVouchers(uid).get();
    return snapshot.docs
        .where((d) => d.id != '_schema')
        .map((d) => UserVoucher.fromMap(d.id, d.data()))
        .toList();
  }

  /// Gives a reward to somebody. Used by an administrator, and by [claim].
  Future<Result<UserVoucher>> grant({
    required String uid,
    required Voucher voucher,
  }) async {
    if (!voucher.isOffered) {
      return Err(voucher.hasExpired
          ? '${voucher.code} has expired'
          : '${voucher.code} is not available');
    }
    try {
      final held = await fetchMine(uid);
      if (held.any((v) => v.voucherId == voucher.id && v.isUsable)) {
        return Err('They already have ${voucher.code}');
      }
      final id = _uuid.v4();
      final mine = UserVoucher.fromVoucher(voucher, id: id);
      await refs.userVouchers(uid).doc(id).set({
        ...mine.toMap(),
        'grantedAt': FieldValue.serverTimestamp(),
      });
      return Ok(mine);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not give out that reward'));
    }
  }

  /// A customer typing a code to claim it for themselves.
  Future<Result<UserVoucher>> claim({
    required String uid,
    required String code,
  }) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) return const Err('Enter a code');
    try {
      final catalogue = await fetchCatalogue();
      final match = catalogue.where((v) => v.code == wanted).toList();
      if (match.isEmpty) return Err('No reward found for $wanted');
      return await grant(uid: uid, voucher: match.first);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not claim that code'));
    }
  }

  /// Marks a held reward as spent, and counts it against the campaign.
  ///
  /// A transaction, so a reward cannot be marked used without being counted,
  /// or counted without being marked used — and so two orders placed at the
  /// same moment cannot both spend it: the reward is re-read inside the
  /// transaction and refused if it is no longer available.
  Future<Result<void>> redeem({
    required String uid,
    required UserVoucher held,
    required String orderId,
  }) async {
    if (!held.isUsable) {
      return Err(held.hasExpired
          ? 'That reward has expired'
          : 'That reward has already been used');
    }
    try {
      final mine = refs.userVouchers(uid).doc(held.id);
      final campaign = held.voucherId.isEmpty ? null : refs.voucher(held.voucherId);
      final refusal = await refs.db.runTransaction<String?>((tx) async {
        final current = await tx.get(mine);
        if (!current.exists) return 'That reward has already been used';
        final live = UserVoucher.fromMap(current.id, current.data() ?? {});
        if (!live.isUsable) {
          return live.hasExpired
              ? 'That reward has expired'
              : 'That reward has already been used';
        }
        // Spin prizes have no campaign, and a campaign may since have been
        // deleted; either way the reward itself must still be spent.
        final counted = campaign == null ? null : await tx.get(campaign);
        tx.update(mine, {
          'status': VoucherStatus.used.name,
          'redeemedAt': FieldValue.serverTimestamp(),
          'orderId': orderId,
        });
        if (counted != null && counted.exists) {
          tx.update(campaign!, {'redeemedCount': FieldValue.increment(1)});
        }
        return null;
      });
      return refusal == null ? const Ok(null) : Err(refusal);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not apply that reward'));
    }
  }

  static String _readable(FirebaseException e, String fallback) =>
      e.code == 'permission-denied'
          ? 'You do not have permission to do that'
          : e.message ?? fallback;
}
