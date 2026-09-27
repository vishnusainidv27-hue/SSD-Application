import 'package:cloud_firestore/cloud_firestore.dart';

/// An in-app notification (Firestore collection: `notifications`) — the
/// Spark-plan substitute for real push (Requirements §2.4, §7): no server
/// exists to trigger FCM, so every app shows these via a live Firestore
/// listener instead. Built in Phase 8 (the writer side already existed since
/// Phase 5's approve/reject flow).
class NotificationModel {
  final String id;
  final String targetUserRef;
  final String type;
  final String message;
  final bool read;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.targetUserRef,
    required this.type,
    required this.message,
    this.read = false,
    this.createdAt,
  });

  factory NotificationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return NotificationModel(
      id: doc.id,
      targetUserRef: data['targetUserRef'] as String? ?? '',
      type: data['type'] as String? ?? '',
      message: data['message'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'targetUserRef': targetUserRef,
        'type': type,
        'message': message,
        'read': read,
      };
}
