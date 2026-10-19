import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/group_session.dart';
import '../models/order.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// Platform-level figures for the admin dashboard.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.suspendedUsers,
    required this.totalOrders,
    required this.activeOrders,
    required this.groupOrders,
    required this.revenue,
    required this.liveSessions,
    required this.openTickets,
  });

  final int totalUsers;
  final int suspendedUsers;
  final int totalOrders;
  final int activeOrders;
  final int groupOrders;
  final double revenue;
  final int liveSessions;
  final int openTickets;

  /// The share of orders placed as a group — the headline KPI for whether
  /// Gather is being used for the thing it exists to do.
  double get groupShare => totalOrders == 0 ? 0 : groupOrders / totalOrders;

  static const empty = AdminStats(
    totalUsers: 0,
    suspendedUsers: 0,
    totalOrders: 0,
    activeOrders: 0,
    groupOrders: 0,
    revenue: 0,
    liveSessions: 0,
    openTickets: 0,
  );
}

/// Administrative functions (FR29–FR32).
class AdminService {
  AdminService(this.refs);

  final FirestoreRefs refs;

  Stream<List<AppUser>> watchUsers() => refs.users
      .snapshots()
      .map((s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  Stream<List<GroupSession>> watchSessions() => refs.sessions
      .snapshots()
      .map((s) => s.docs.map((d) => GroupSession.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0))));

  /// Suspends or restores an account (US17-AC5). A suspended user is signed
  /// out on their next sign-in attempt.
  Future<Result<void>> setAccountStatus({
    required String uid,
    required AccountStatus status,
  }) async {
    try {
      await refs.user(uid).update({'status': status.name});
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that account');
    }
  }

  Future<Result<void>> setRole({required String uid, required UserRole role}) async {
    try {
      await refs.user(uid).update({'role': role.name});
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that account');
    }
  }

  /// Derives dashboard figures from the collections the admin can already
  /// read. Kept as a one-shot read rather than a stream so opening the
  /// dashboard does not hold several large listeners open.
  Future<AdminStats> loadStats() async {
    try {
      final results = await Future.wait([
        refs.users.get(),
        refs.orders.get(),
        refs.sessions.get(),
        refs.tickets.where('status', isEqualTo: 'open').get(),
      ]);

      final users = results[0].docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
      final orders = results[1].docs.map((d) => FoodOrder.fromMap(d.id, d.data())).toList();
      final sessions = results[2].docs.map((d) => GroupSession.fromMap(d.id, d.data())).toList();

      return AdminStats(
        totalUsers: users.length,
        suspendedUsers: users.where((u) => u.isSuspended).length,
        totalOrders: orders.length,
        activeOrders: orders.where((o) => o.status.isActive).length,
        groupOrders: orders.where((o) => o.isGroupOrder).length,
        revenue: orders
            .where((o) => o.status != OrderStatus.cancelled)
            .fold<double>(0, (acc, o) => acc + o.total),
        liveSessions: sessions.where((s) => s.stage.isLive).length,
        openTickets: results[3].docs.length,
      );
    } on FirebaseException {
      return AdminStats.empty;
    }
  }
}
