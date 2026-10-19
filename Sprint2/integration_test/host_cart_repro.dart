import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';

/// Reproduces the report: the host cannot see the shared cart, while a member
/// sees every line. Reads the cart both ways — one-shot and through the live
/// stream the screen actually uses.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the host can read the shared cart', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signOut();
    final c = ProviderContainer();
    final auth = c.read(authServiceProvider);
    final sessions = c.read(sessionServiceProvider);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    const pw = 'TestPass123!';
    final hostEmail = 'rh$stamp@gather-test.local';
    final memEmail = 'rm$stamp@gather-test.local';

    Future<AppUser> actAs(String e) async {
      await FirebaseAuth.instance.signOut();
      final r = await auth.signIn(email: e, password: pw);
      expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
      return r.valueOrNull!;
    }

    final h = await auth.signUp(fullName: 'Repro Host', username: 'rh$stamp',
        email: hostEmail, phone: '+96659000${stamp % 10000}', password: pw);
    final m = await auth.signUp(fullName: 'Repro Member', username: 'rm$stamp',
        email: memEmail, phone: '+96659100${stamp % 10000}', password: pw);
    var host = h.valueOrNull!, member = m.valueOrNull!;

    host = await actAs(hostEmail);
    final created = await sessions.createSession(host: host, name: 'Repro');
    final sid = created.valueOrNull!.id;

    member = await actAs(memEmail);
    await sessions.joinByCode(code: created.valueOrNull!.code, user: member);

    // host chooses the restaurant, as Reema did
    host = await actAs(hostEmail);
    final restaurant = (await c.read(catalogServiceProvider).fetchRestaurants()).first;
    final menu = await c.read(catalogServiceProvider).fetchMenu(restaurant.id);
    final chose = await sessions.chooseRestaurant(sessionId: sid, restaurant: restaurant);
    expect(chose.isSuccess, isTrue, reason: chose.errorOrNull ?? '');

    // host adds two items
    for (var i = 0; i < 2; i++) {
      final r = await sessions.addLine(
          sessionId: sid, item: menu[i], owner: host, quantity: 1);
      expect(r.isSuccess, isTrue, reason: 'host add $i: ${r.errorOrNull}');
    }
    debugPrint('REPRO host added 2');

    // member adds two items
    member = await actAs(memEmail);
    for (var i = 0; i < 2; i++) {
      final r = await sessions.addLine(
          sessionId: sid, item: menu[i], owner: member, quantity: 1);
      expect(r.isSuccess, isTrue, reason: 'member add $i: ${r.errorOrNull}');
    }
    final asMemberFetch = await sessions.fetchLines(sid);
    final asMemberStream = await sessions.watchLines(sid).first;
    debugPrint('REPRO member sees fetch=${asMemberFetch.valueOrNull?.length} '
        'stream=${asMemberStream.length}');

    // now read the very same cart as the host
    host = await actAs(hostEmail);
    final s = await sessions.fetch(sid);
    debugPrint('REPRO session memberIds=${s!.memberIds} hostId=${s.hostId} '
        'hostUid=${host.uid}');
    final asHostFetch = await sessions.fetchLines(sid);
    debugPrint('REPRO host fetch ok=${asHostFetch.isSuccess} '
        'n=${asHostFetch.valueOrNull?.length} err=${asHostFetch.errorOrNull}');

    List<CartLine> hostStream = const [];
    Object? streamError;
    try {
      hostStream = await sessions.watchLines(sid).first;
    } catch (e) {
      streamError = e;
    }
    debugPrint('REPRO host stream n=${hostStream.length} error=$streamError');

    expect(asHostFetch.isSuccess, isTrue,
        reason: 'the host must be able to read the shared cart');
    expect(asHostFetch.valueOrNull, hasLength(4),
        reason: 'the host must see all four lines');
    expect(streamError, isNull, reason: 'the live stream must not error for the host');
    expect(hostStream, hasLength(4), reason: 'the screen reads this stream');

    await actAs(hostEmail);
    await sessions.cancel(sid);
    for (final e in [hostEmail, memEmail]) {
      await actAs(e);
      await FirebaseAuth.instance.currentUser?.delete();
    }
    c.dispose();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
