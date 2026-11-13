import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';

/// Checks the privilege rules on users/{uid} against the live project:
/// an ordinary user may edit their own profile but may not grant themselves
/// the admin role, and the administrator account still reads as an admin.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a user can edit their profile but cannot become an admin',
      (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signOut();

    final container = ProviderContainer();
    final auth = container.read(authServiceProvider);
    final refs = container.read(firestoreRefsProvider);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final signUp = await auth.signUp(
      fullName: 'Rules Probe',
      username: 'probe$stamp',
      email: 'probe$stamp@gather-test.local',
      phone: '+96652222${stamp % 10000}',
      password: 'TestPass123!',
    );
    expect(signUp.isSuccess, isTrue, reason: signUp.errorOrNull ?? '');
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 1. An ordinary profile edit must still be allowed.
    final edit = await auth.updateProfile(uid: uid, fullName: 'Rules Probe Two');
    expect(edit.isSuccess, isTrue,
        reason: 'editing your own name must still work: ${edit.errorOrNull}');
    debugPrint('RULES ordinary profile edit: ALLOWED (correct)');

    // 2. Self-promotion to admin must be refused.
    var escalated = false;
    try {
      await refs.user(uid).update({'role': 'admin'});
      escalated = true;
    } on FirebaseException catch (e) {
      debugPrint('RULES self-promotion refused: ${e.code} (correct)');
    }
    expect(escalated, isFalse,
        reason: 'a user must not be able to grant themselves the admin role');

    // 3. Suspending yourself must also be refused.
    var changedStatus = false;
    try {
      await refs.user(uid).update({'status': 'suspended'});
      changedStatus = true;
    } on FirebaseException catch (e) {
      debugPrint('RULES status change refused: ${e.code} (correct)');
    }
    expect(changedStatus, isFalse);

    // 4. The role on disk is untouched.
    final after = await auth.loadProfile(uid);
    expect(after!.isAdmin, isFalse);

    await FirebaseAuth.instance.currentUser?.delete();

    // 5. The administrator account still reads as an administrator.
    final admin = await auth.signIn(
        email: 'admin@gather.app', password: 'GatherAdmin2026!');
    expect(admin.isSuccess, isTrue, reason: admin.errorOrNull ?? '');
    expect(admin.valueOrNull!.isAdmin, isTrue,
        reason: 'the admin account must still hold the admin role');
    debugPrint('RULES admin account still admin: YES (correct)');

    await FirebaseAuth.instance.signOut();
    container.dispose();
    debugPrint('RULES-CHECK-PASSED');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
