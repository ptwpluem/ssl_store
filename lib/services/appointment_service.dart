import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/appointment.dart';
import '../models/gold_asset.dart';
import '../models/notification_item.dart';
import 'firestore_helper.dart';
import 'id_generator_service.dart';

/// Manages pickup appointments for physical gold bars.
class AppointmentService {
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal();

  final IdGeneratorService _ids = IdGeneratorService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// Stream of appointments for the currently logged-in user, sorted by date.
  Stream<List<Appointment>> getAppointmentsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: uid)
        // Note: orderBy is intentionally omitted here to avoid requiring a
        // composite Firestore index (userId + date) that may not yet be
        // deployed. Results are sorted client-side below instead.
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Appointment.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date)); // ascending — soonest first
          return list;
        });
  }

  /// Owner-facing stream of all scheduled appointments, sorted by date.
  /// Filters status in Dart so only a single-field index on 'date' is needed —
  /// avoids the composite (status, date) index that may not be deployed yet.
  Stream<List<Appointment>> getAllScheduledAppointmentsStream() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromMap(doc.id, doc.data()))
            .where((apt) => apt.status == 'scheduled')
            .toList());
  }

  // ─── Queries ──────────────────────────────────────────────────────────────

  Future<List<Appointment>> getAppointmentsForDate(DateTime date) async {
    // Use Firestore Timestamps for range queries — ISO strings sorted
    // lexicographically and break for cross-year or cross-month comparisons.
    final start = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final end   = Timestamp.fromDate(DateTime(date.year, date.month, date.day, 23, 59, 59));

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();

    return snapshot.docs
        .map((doc) => Appointment.fromMap(doc.id, doc.data()))
        .where((apt) => apt.status == 'scheduled')
        .toList();
  }

  // ─── Create ───────────────────────────────────────────────────────────────

  Future<void> createAppointment({
    required GoldAsset asset,
    required DateTime appointmentDate,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    // Capacity check: max 2 bookings per time slot
    final apptTimestamp = Timestamp.fromDate(appointmentDate);
    final existing = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: apptTimestamp)
        .get();

    final scheduledCount =
        existing.docs.where((d) => d.data()['status'] == 'scheduled').length;
    if (scheduledCount >= 2) {
      throw Exception('This time slot has reached maximum capacity.');
    }

    final aptId = await _ids.generateId('appointments');
    final appointment = Appointment(
      id: aptId,
      userId: uid,
      assetId: asset.id,
      assetName: asset.name,
      date: appointmentDate,
      status: 'scheduled',
    );

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.set(
        FirebaseFirestore.instance.collection('appointments').doc(aptId),
        appointment.toMap(),
      );
      final userRef = await getUserDocRef(uid);
      tx.update(userRef.collection('assets').doc(asset.id), {
        'status': 'pickup_scheduled',
      });
    });
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  Future<void> updateAppointment(
      String appointmentId, DateTime newDate) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final newTimestamp = Timestamp.fromDate(newDate);
    final existing = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: newTimestamp)
        .get();

    final scheduledCount = existing.docs
        .where((d) =>
            d.data()['status'] == 'scheduled' && d.id != appointmentId)
        .length;
    if (scheduledCount >= 2) {
      throw Exception('This time slot has reached maximum capacity.');
    }

    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'date': newTimestamp});
  }

  // ─── Cancel ───────────────────────────────────────────────────────────────

  Future<void> cancelAppointment(
      String appointmentId, String assetId) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final userRef = await getUserDocRef(uid);
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(
        FirebaseFirestore.instance.collection('appointments').doc(appointmentId));
    batch.update(userRef.collection('assets').doc(assetId), {'status': 'owned'});
    await batch.commit();
  }

  // ─── Complete (owner action) ──────────────────────────────────────────────

  Future<void> completeAppointment({
    required String userId,
    required String appointmentId,
    required String assetId,
    required String assetName,
  }) async {
    // Resolve all async work BEFORE entering the transaction —
    // async I/O inside runTransaction breaks atomicity guarantees.
    final userRef = await getUserDocRef(userId);
    final notifId = await _ids.generateId('notifications');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(
        FirebaseFirestore.instance.collection('appointments').doc(appointmentId),
        {'status': 'completed'},
      );
      tx.update(userRef.collection('assets').doc(assetId), {'status': 'collected'});
      tx.set(userRef.collection('notifications').doc(notifId), NotificationItem(
        id: notifId,
        title: 'รับสินค้าสำเร็จ',
        message: 'คุณรับมอบ $assetName จากทางร้านเรียบร้อยแล้ว',
        type: 'appointment',
        timestamp: DateTime.now(),
        isRead: false,
      ).toMap());
    });
  }

  // ─── History stream (owner) ───────────────────────────────────────────────

  /// All appointments (any status), most recent first — used for the history tab.
  /// Single-field orderBy needs no composite index.
  Stream<List<Appointment>> getAllAppointmentsStream() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromMap(doc.id, doc.data()))
            .toList());
  }
}
