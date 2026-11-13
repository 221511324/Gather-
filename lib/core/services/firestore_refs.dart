import 'package:cloud_firestore/cloud_firestore.dart';

/// Every collection path in one place.
///
/// Layout:
/// ```
/// users/{uid}                     profile, settings, favourites
///   cart/{lineId}                 personal cart
///   vouchers/{id}                 rewards this user holds
///   savedSessions/{id}            reusable groups
///   paymentMethods/{id}           saved cards
///   notifications/{id}            notification centre
///   aiChat/{id}                   assistant transcript
/// usernames/{usernameLower}       uniqueness index -> { uid }
/// sessionCodes/{code}             active 4-digit code -> { sessionId }
/// restaurants/{id}
///   menu/{itemId}
/// sessions/{id}                   group ordering session
///   lines/{lineId}                the shared cart
/// paymentOptions/{id}            what the platform accepts (admin managed)
/// orders/{id}
/// vouchers/{id}                   reward catalogue (admin managed)
/// stories/{id}                    a shared food photo (US19)
///   media/image                   its picture, base64, kept apart so the
///                                 feed can be listed without it
/// tickets/{id}                    support issues
/// meta/{doc}                      seed bookkeeping
/// ```
class FirestoreRefs {
  FirestoreRefs(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get users => db.collection('users');
  DocumentReference<Map<String, dynamic>> user(String uid) => users.doc(uid);

  CollectionReference<Map<String, dynamic>> cart(String uid) => user(uid).collection('cart');
  CollectionReference<Map<String, dynamic>> userVouchers(String uid) => user(uid).collection('vouchers');
  CollectionReference<Map<String, dynamic>> savedSessions(String uid) => user(uid).collection('savedSessions');
  CollectionReference<Map<String, dynamic>> paymentMethods(String uid) => user(uid).collection('paymentMethods');
  CollectionReference<Map<String, dynamic>> notifications(String uid) => user(uid).collection('notifications');
  CollectionReference<Map<String, dynamic>> aiChat(String uid) => user(uid).collection('aiChat');

  CollectionReference<Map<String, dynamic>> get usernames => db.collection('usernames');
  DocumentReference<Map<String, dynamic>> username(String handle) => usernames.doc(handle.toLowerCase());

  CollectionReference<Map<String, dynamic>> get sessionCodes => db.collection('sessionCodes');
  DocumentReference<Map<String, dynamic>> sessionCode(String code) => sessionCodes.doc(code);

  CollectionReference<Map<String, dynamic>> get restaurants => db.collection('restaurants');
  DocumentReference<Map<String, dynamic>> restaurant(String id) => restaurants.doc(id);
  CollectionReference<Map<String, dynamic>> menu(String restaurantId) => restaurant(restaurantId).collection('menu');

  CollectionReference<Map<String, dynamic>> get sessions => db.collection('sessions');
  DocumentReference<Map<String, dynamic>> session(String id) => sessions.doc(id);
  CollectionReference<Map<String, dynamic>> sessionLines(String sessionId) => session(sessionId).collection('lines');

  CollectionReference<Map<String, dynamic>> get paymentOptions =>
      db.collection('paymentOptions');
  DocumentReference<Map<String, dynamic>> paymentOption(String id) =>
      paymentOptions.doc(id);

  CollectionReference<Map<String, dynamic>> get orders => db.collection('orders');
  DocumentReference<Map<String, dynamic>> order(String id) => orders.doc(id);

  CollectionReference<Map<String, dynamic>> get vouchers => db.collection('vouchers');
  DocumentReference<Map<String, dynamic>> voucher(String id) => vouchers.doc(id);

  CollectionReference<Map<String, dynamic>> get stories => db.collection('stories');
  DocumentReference<Map<String, dynamic>> story(String id) => stories.doc(id);

  /// The picture, in its own document. Firestore reads whole documents, so
  /// keeping it apart is what makes listing the feed cheap.
  DocumentReference<Map<String, dynamic>> storyImage(String id) =>
      story(id).collection('media').doc('image');

  CollectionReference<Map<String, dynamic>> get tickets => db.collection('tickets');
  DocumentReference<Map<String, dynamic>> ticket(String id) => tickets.doc(id);

  DocumentReference<Map<String, dynamic>> meta(String doc) => db.collection('meta').doc(doc);
}
