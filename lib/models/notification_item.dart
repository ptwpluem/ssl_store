import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // pawn, cart, store, appointment, price
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
  });

  factory NotificationItem.fromMap(String id, Map<String, dynamic> data) {
    return NotificationItem(
      id: id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'info',
      // Handle both Firestore Timestamp (new) and ISO string (legacy records).
      timestamp: _parseTimestamp(data['timestamp']),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      // Store as Firestore Timestamp — consistent with all other time fields
      // and required for server-side ordering queries.
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
