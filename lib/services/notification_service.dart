import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_item.dart';
import 'firestore_helper.dart';

/// Manages per-user push notifications stored in Firestore.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Stream ───────────────────────────────────────────────────────────────

  Stream<List<NotificationItem>> getNotificationsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return Stream.fromFuture(getUserDocRef(uid)).asyncExpand((userRef) {
      final collection = userRef.collection('notifications');
      return collection
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => NotificationItem.fromMap(doc.id, doc.data()))
              .toList());
    });
  }

  // ─── Read management ──────────────────────────────────────────────────────

  Future<void> markNotificationAsRead(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    final userRef = await getUserDocRef(uid);
    await userRef.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsAsRead() async {
    final uid = _uid;
    if (uid == null) return;

    final userRef = await getUserDocRef(uid);
    final unreadDocs = await userRef
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadDocs.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ─── Deletion ─────────────────────────────────────────────────────────────

  Future<void> deleteNotification(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    final userRef = await getUserDocRef(uid);
    await userRef.collection('notifications').doc(notificationId).delete();
  }

  Future<void> clearAllNotifications() async {
    final uid = _uid;
    if (uid == null) return;

    final userRef = await getUserDocRef(uid);
    final allDocs = await userRef.collection('notifications').get();

    if (allDocs.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in allDocs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
