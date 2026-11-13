import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/voucher_service.dart';
import 'package:gather/firebase_options.dart';

/// Sprint 3 — rewards and vouchers, TC_R_001 to TC_R_010.
///
/// US15  Allows users to view available rewards and apply eligible vouchers
///       or discounts to orders.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  const adminEmail = 'admin@gather.app';
  const adminPassword = 'GatherAdmin2026!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final meEmail = 'r3me$stamp@gather-test.local';
  final code = 'TEST$stamp'.substring(0, 10);

  late ProviderContainer c;
  late VoucherService vouchers;
  late AppUser me;
  late Voucher campaign;

  Future<void> asAdmin() async {
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: adminEmail, password: adminPassword);
  }

  Future<AppUser> asMe() async {
    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signIn(email: meEmail, password: password);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    return r.valueOrNull!;
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    c = ProviderContainer();
    vouchers = c.read(voucherServiceProvider);

    final reg = await c.read(authServiceProvider).signUp(
        fullName: 'R Me', username: 'r3u$stamp', email: meEmail,
        phone: '+96652${stamp % 100000}', password: password);
    expect(reg.isSuccess, isTrue, reason: reg.errorOrNull ?? '');
    me = reg.valueOrNull!;
  });

  tearDownAll(() async {
    await asAdmin();
    await vouchers.delete(campaign.id);
    c.dispose();
  });

  // ------------------------------------------------- US15, administrator ---

  testWidgets('TC_R_001 An administrator can create a reward', (t) async {
    await asAdmin();
    final r = await vouchers.upsert(Voucher(
      id: '', code: code, title: '20% off your group order',
      discountType: DiscountType.percentage, discountValue: 20,
      minimumOrder: 50,
    ));
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    campaign = r.valueOrNull!;
    expect(campaign.code, code.toUpperCase());
    expect(campaign.redeemedCount, 0);
    debugPrint('TC_R_001 PASS created ${campaign.code}');
  });

  testWidgets('TC_R_002 The same code cannot be used twice', (t) async {
    // Everything else about it must be valid, or this would be refused for
    // the wrong reason and the duplicate check would never be reached.
    final r = await vouchers.upsert(Voucher(
        id: '', code: code.toLowerCase(), title: 'Duplicate',
        discountType: DiscountType.percentage, discountValue: 5));
    expect(r.isSuccess, isFalse, reason: 'codes must be unique whatever the case');
    expect(r.errorOrNull, contains('already in use'),
        reason: 'and refused *because* it is a duplicate');
    debugPrint('TC_R_002 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_R_003 Nonsense discounts are refused', (t) async {
    for (final (what, v) in [
      ('over 100 per cent', Voucher(id: '', code: 'PCT$stamp', title: 'x',
          discountValue: 150)),
      ('zero value', Voucher(id: '', code: 'ZERO$stamp', title: 'x',
          discountValue: 0)),
      ('no name', Voucher(id: '', code: 'NAME$stamp', title: '  ',
          discountValue: 10)),
      ('code too short', Voucher(id: '', code: 'AB', title: 'x',
          discountValue: 10)),
    ]) {
      final r = await vouchers.upsert(v);
      expect(r.isSuccess, isFalse, reason: 'must refuse $what');
      debugPrint('TC_R_003   $what -> "${r.errorOrNull}"');
    }
    debugPrint('TC_R_003 PASS all four refused');
  });

  // ------------------------------------------------------ US15, customer ---

  testWidgets('TC_R_004 A customer can claim a code', (t) async {
    me = await asMe();
    final r = await vouchers.claim(uid: me.uid, code: code.toLowerCase());
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    expect(r.valueOrNull!.code, code.toUpperCase());
    expect(r.valueOrNull!.discountValue, 20, reason: 'terms copied from the campaign');

    final mine = await vouchers.fetchMine(me.uid);
    expect(mine.where((v) => v.code == code.toUpperCase()), hasLength(1));
    debugPrint('TC_R_004 PASS claimed, holds ${mine.length}');
  });

  testWidgets('TC_R_005 The same reward cannot be claimed twice', (t) async {
    final r = await vouchers.claim(uid: me.uid, code: code);
    expect(r.isSuccess, isFalse);
    debugPrint('TC_R_005 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_R_006 An unknown code is refused', (t) async {
    final r = await vouchers.claim(uid: me.uid, code: 'NOTAREALCODE');
    expect(r.isSuccess, isFalse);
    debugPrint('TC_R_006 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_R_007 The discount is worked out against the real order', (t) async {
    final held = (await vouchers.fetchMine(me.uid))
        .firstWhere((v) => v.code == code.toUpperCase());

    // Below the minimum it is worth nothing.
    expect(held.discountOn(subtotal: 49, deliveryFee: 10), 0);
    // At and above, 20 per cent of the items only.
    expect(held.discountOn(subtotal: 50, deliveryFee: 10), 10);
    expect(held.discountOn(subtotal: 200, deliveryFee: 10), 40);
    debugPrint('TC_R_007 PASS 0 under the minimum, 40 on a 200 SAR order');
  });

  testWidgets('TC_R_008 Redeeming marks it used and counts it', (t) async {
    me = await asMe();
    final held = (await vouchers.fetchMine(me.uid))
        .firstWhere((v) => v.code == code.toUpperCase());

    final r = await vouchers.redeem(
        uid: me.uid, held: held, orderId: 'test-order-$stamp');
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final after = (await vouchers.fetchMine(me.uid))
        .firstWhere((v) => v.id == held.id);
    expect(after.status, VoucherStatus.used);
    expect(after.orderId, 'test-order-$stamp');
    expect(after.isUsable, isFalse);

    // And the campaign counted it — a customer is allowed to do that one
    // increment and nothing else.
    final catalogue = await vouchers.fetchCatalogue();
    final counted = catalogue.firstWhere((v) => v.id == campaign.id);
    expect(counted.redeemedCount, 1);
    debugPrint('TC_R_008 PASS used, campaign count now ${counted.redeemedCount}');
  });

  testWidgets('TC_R_009 A used reward cannot be redeemed again', (t) async {
    final held = (await vouchers.fetchMine(me.uid))
        .firstWhere((v) => v.code == code.toUpperCase());
    final r = await vouchers.redeem(uid: me.uid, held: held, orderId: 'second');
    expect(r.isSuccess, isFalse);
    debugPrint('TC_R_009 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_R_010 A customer cannot create or alter a campaign', (t) async {
    me = await asMe();

    final created = await vouchers.upsert(
        Voucher(id: '', code: 'FREE$stamp', title: 'Free everything',
            discountValue: 100));
    expect(created.isSuccess, isFalse, reason: 'only an administrator may create one');

    // Nor edit an existing campaign's terms directly.
    var refused = false;
    try {
      await c.read(firestoreRefsProvider)
          .voucher(campaign.id)
          .update({'discountValue': 99});
    } catch (_) {
      refused = true;
    }
    expect(refused, isTrue, reason: 'a customer must not be able to rewrite the terms');
    debugPrint('TC_R_010 PASS create refused="${created.errorOrNull}", edit refused');
  });
}
