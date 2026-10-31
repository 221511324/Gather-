import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';

/// Creates (or repairs) the shared administrator account used to demonstrate
/// the admin dashboard. Safe to run more than once.
///
///   `flutter test integration_test/create_admin.dart -d <device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = 'admin@gather.app';
  const password = 'GatherAdmin2026!';
  const username = 'admin';

  testWidgets('the administrator account exists and holds the admin role',
      (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signOut();

    final container = ProviderContainer();
    final auth = container.read(authServiceProvider);
    final refs = container.read(firestoreRefsProvider);

    // Create it if it is not there; otherwise just sign in.
    final created = await auth.signUp(
      fullName: 'Gather Admin',
      username: username,
      email: email,
      phone: '+966500000001',
      password: password,
    );
    if (created.isSuccess) {
      debugPrint('ADMIN created');
    } else {
      debugPrint('ADMIN already exists: ${created.errorOrNull}');
      final signedIn = await auth.signIn(email: email, password: password);
      expect(signedIn.isSuccess, isTrue,
          reason: 'the account exists but the password did not match: '
              '${signedIn.errorOrNull}');
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await refs.user(uid).update({'role': 'admin'});

    final doc = await refs.user(uid).get();
    expect(doc.data()!['role'], 'admin');
    debugPrint('ADMIN uid=$uid role=${doc.data()!['role']}');

    // Prove it through the model the app actually reads.
    final profile = await auth.loadProfile(uid);
    expect(profile!.isAdmin, isTrue);
    debugPrint('ADMIN-READY email=$email');

    await FirebaseAuth.instance.signOut();
    container.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
