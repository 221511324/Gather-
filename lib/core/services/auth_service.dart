import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// Account creation, sign-in and profile persistence (FR1, FR2, FR29).
class AuthService {
  AuthService({required this.auth, required this.refs});

  final FirebaseAuth auth;
  final FirestoreRefs refs;

  Stream<User?> authStateChanges() => auth.authStateChanges();
  User? get currentUser => auth.currentUser;
  String? get uid => auth.currentUser?.uid;

  /// Live profile for the signed-in user. Returns null while signed out or
  /// before the profile document has been written.
  Stream<AppUser?> watchProfile(String uid) =>
      refs.user(uid).snapshots().map((d) => d.exists ? AppUser.fromMap(d.id, d.data() ?? {}) : null);

  Future<AppUser?> loadProfile(String uid) async {
    final doc = await refs.user(uid).get();
    return doc.exists ? AppUser.fromMap(doc.id, doc.data() ?? {}) : null;
  }

  // ------------------------------------------------------------- usernames --

  /// Usernames are the handle hosts type when inviting someone (FR7), so they
  /// have to be unique. `usernames/{lowercase}` is the uniqueness index.
  Future<bool> isUsernameAvailable(String username) async {
    final handle = username.trim().toLowerCase();
    if (handle.isEmpty) return false;
    final doc = await refs.username(handle).get();
    return !doc.exists;
  }

  static String? validateUsername(String value) {
    final handle = value.trim();
    if (handle.length < 3) return 'Username must be at least 3 characters';
    if (handle.length > 20) return 'Username must be 20 characters or fewer';
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(handle)) {
      return 'Use letters, numbers, dots and underscores only';
    }
    return null;
  }

  // ------------------------------------------------------------ sign up/in --

  Future<Result<AppUser>> signUp({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    final handle = username.trim().toLowerCase();
    final indexRef = refs.username(handle);

    // Check before creating the auth user so a taken handle does not leave an
    // orphaned account behind.
    if ((await indexRef.get()).exists) {
      return const Err('That username is already taken');
    }

    UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      return Err(_authMessage(e));
    }

    final newUid = credential.user!.uid;
    final profile = AppUser(
      uid: newUid,
      username: username.trim(),
      fullName: fullName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
    );

    try {
      // Claim the handle and write the profile together. If the handle was
      // taken in the gap above, the transaction fails and we roll the auth
      // user back rather than leaving a profile-less account.
      await refs.db.runTransaction((tx) async {
        final snapshot = await tx.get(indexRef);
        if (snapshot.exists) {
          throw FirebaseException(plugin: 'gather', code: 'username-taken');
        }
        tx.set(indexRef, {'uid': newUid, 'username': profile.username, 'createdAt': FieldValue.serverTimestamp()});
        tx.set(refs.user(newUid), {
          ...profile.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      await credential.user?.delete().catchError((_) {});
      if (e.code == 'username-taken') return const Err('That username was just taken');
      return Err('Could not finish creating your account: ${e.message ?? e.code}');
    }

    await credential.user?.updateDisplayName(profile.fullName);
    return Ok(profile);
  }

  Future<Result<AppUser>> signIn({required String email, required String password}) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final profile = await loadProfile(credential.user!.uid);
      if (profile == null) {
        await auth.signOut();
        return const Err('No Gather profile is linked to this account');
      }
      if (profile.isSuspended) {
        await auth.signOut();
        return const Err('This account has been suspended. Contact support for help.');
      }
      return Ok(profile);
    } on FirebaseAuthException catch (e) {
      return Err(_authMessage(e));
    }
  }

  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(_authMessage(e));
    }
  }

  Future<void> signOut() => auth.signOut();

  // -------------------------------------------------------------- profile ---

  Future<Result<void>> updateProfile({
    required String uid,
    String? fullName,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      await refs.user(uid).update({
        if (fullName != null) 'fullName': fullName.trim(),
        if (phone != null) 'phone': phone.trim(),
        'photoUrl': ?photoUrl,
      });
      if (fullName != null) await auth.currentUser?.updateDisplayName(fullName.trim());
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not save your profile');
    }
  }

  // -------------------------------------------------------- member lookup ---

  /// Resolves an invite target typed by the host (FR7). Accepts a username or
  /// a phone number and respects the target's discoverability settings.
  Future<Result<AppUser>> findInvitee(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const Err('Enter a username or phone number');

    final looksLikePhone = RegExp(r'^[+0-9\s-]{6,}$').hasMatch(value);
    if (looksLikePhone) {
      final normalized = value.replaceAll(RegExp(r'[\s-]'), '');
      final byPhone = await refs.users.where('phone', isEqualTo: normalized).limit(1).get();
      if (byPhone.docs.isEmpty) return const Err('No Gather user has that phone number');
      final found = AppUser.fromMap(byPhone.docs.first.id, byPhone.docs.first.data());
      if (!found.settings.discoverableByPhone) {
        return const Err('That user cannot be added by phone number');
      }
      return Ok(found);
    }

    final handle = await refs.username(value.toLowerCase()).get();
    if (!handle.exists) return const Err('No Gather user with that username');
    final ownerUid = (handle.data() ?? {})['uid'];
    if (ownerUid is! String) return const Err('No Gather user with that username');
    final found = await loadProfile(ownerUid);
    if (found == null) return const Err('No Gather user with that username');
    if (!found.settings.discoverableByUsername) {
      return const Err('That user cannot be added by username');
    }
    return Ok(found);
  }

  static String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address is not valid',
        'user-disabled' => 'This account has been disabled',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Incorrect email or password',
        'email-already-in-use' => 'An account already exists for that email',
        'weak-password' => 'Choose a password with at least 6 characters',
        'too-many-requests' => 'Too many attempts. Try again in a moment.',
        'network-request-failed' => 'No internet connection',
        'requires-recent-login' => 'Please sign in again to continue',
        _ => e.message ?? 'Something went wrong. Please try again.',
      };
}
