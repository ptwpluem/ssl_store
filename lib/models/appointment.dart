import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String userId;
  final String assetId;
  final String assetName;
  final DateTime date;
  final String status; // 'scheduled', 'completed', 'cancelled'
  final String? purpose; // 'gold_bar_pickup', 'pawn_dropoff', 'consultation', 'purchase_pickup'
  final String? linkedTransactionId; // originating transaction for traceability

  Appointment({
    required this.id,
    required this.userId,
    required this.assetId,
    required this.assetName,
    required this.date,
    this.status = 'scheduled',
    this.purpose,
    this.linkedTransactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'assetId': assetId,
      'assetName': assetName,
      // Store as Firestore Timestamp — enables server-side range queries
      // (e.g. getAppointmentsForDate) and consistent ordering.
      'date': Timestamp.fromDate(date),
      'status': status,
      if (purpose != null) 'purpose': purpose,
      if (linkedTransactionId != null) 'linkedTransactionId': linkedTransactionId,
    };
  }

  factory Appointment.fromMap(String docId, Map<String, dynamic> map) {
    return Appointment(
      id: docId,
      userId: map['userId'] ?? '',
      assetId: map['assetId'] ?? '',
      assetName: map['assetName'] ?? '',
      // Handle both Firestore Timestamp (new) and ISO string (legacy records).
      date: _parseDate(map['date']),
      status: map['status'] ?? 'scheduled',
      purpose: map['purpose'] as String?,
      linkedTransactionId: map['linkedTransactionId'] as String?,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
